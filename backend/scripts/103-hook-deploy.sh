#!/usr/bin/env bash
# HeitjeHulp B4 — zet de B4-hooks op de gedeelde PocketBase-server
# (root@178.104.171.224, map /root/pb_hooks/). ALLEEN deze drie bestanden:
#   NIEUW  hh_klusplaatsen_hulp.js  rekenwerk: tijdregel, leeftijdsgrens,
#                                   voorfilter, controles bij plaatsen
#   NIEUW  hh_klusplaatsen.pb.js    hh_klussen: plaatsen (foto, tijd, vinkje),
#                                   leeftijdsgrens, opnieuw nakijken na een
#                                   wijziging; route /keuren; hh_meldingen:
#                                   geen "nieuwe klus" vóór keuring of voor
#                                   wie te jong is, afkeur-reden in de melding
#   BIJ    hh_klussen.pb.js         accepteren: keuring + leeftijd (B4)
#
# VOORWAARDE: 100-b4-velden.mjs --apply (de velden waar de hooks op leunen).
# Daarna 101-b4-rules.mjs --apply en 104-b4-seed-keuren.mjs --apply.
#
# Zelfde werkwijze als 83 (B2):
#   - nieuwe bestanden mogen; --rollback VERWIJDERT die weer en zet
#     hh_klussen.pb.js terug
#   - ssh_() leest geen stdin (ssh -n): anders eet de diff-lus de "y" op
#   1. node --check lokaal (syntax)
#   2. lijst /root/pb_hooks/ VOOR de kopie
#   2b. verschil serverversie -> lokaal per bestaand bestand (lees dit na: er
#       mag alleen B4 in staan; staat er meer, dan wijkt prod af van git)
#   3. bevestiging (y)
#   4. backup op de server naar /root/hh_hook_backups/b4/<tijd>/ (plus
#      NIEUW.txt met de nieuwe bestanden), dan via /tmp/ naar /root/pb_hooks/
#      (eerst het hulpbestand, dan de hooks die het gebruiken)
#   5. GEEN systemctl restart: PocketBase herlaadt hooks bij een wijziging
#   6. lijst NA de kopie; alleen de nieuwe bestanden mogen erbij
#   7. verify: journalctl -n 20 (let op laadfouten). Het echte bewijs is
#      102-b4check.mjs --apply.
#
#   ./103-hook-deploy.sh            deployen
#   ./103-hook-deploy.sh --rollback laatste backup terugzetten
#   ./103-hook-deploy.sh --verify   alleen stap 7
set -euo pipefail

HOST="root@178.104.171.224"
SLEUTEL="$HOME/.ssh/id_ed25519"
DOELMAP="/root/pb_hooks"
BACKUPMAP="/root/hh_hook_backups/b4"  # eigen submap: --rollback pakt nooit een backup van 83 of B3/B6
# Volgorde telt: hulpbestand eerst. ALLEEN B4-bestanden (afspraak B3/B4/B6).
BESTANDEN=("hh_klusplaatsen_hulp.js" "hh_klusplaatsen.pb.js" "hh_klussen.pb.js")
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRONMAP="$HIER/../pb_hooks"
VOOR=/tmp/hh_hooks_voor_103.txt
NA=/tmp/hh_hooks_na_103.txt

ssh_() { ssh -n -i "$SLEUTEL" -o BatchMode=yes -o ConnectTimeout=10 "$HOST" "$@"; }

verify() {
  echo
  echo "VERIFY: journalctl -u pocketbase.service -n 20 (let op fouten)"
  ssh_ "journalctl -u pocketbase.service -n 20 --no-pager" | sed 's/^/  /'
  echo
  echo "  Bewijs: node scripts/102-b4check.mjs --apply (en 82, 72, 62, 04, 50)"
}

# Verschil tussen de lijst voor en na; [verwacht] = bestanden die erbij of
# eraf mochten (spatie-gescheiden).
lijst_klopt() {
  local verwacht="$1" verschil regel naam
  verschil=$(diff "$VOOR" "$NA" || true)
  local fout=0
  while IFS= read -r regel; do
    [[ "$regel" =~ ^[\<\>]\ (.*)$ ]] || continue
    naam="${BASH_REMATCH[1]}"
    if [[ " $verwacht " == *" $naam "* ]]; then
      echo "   ✓ verwacht: $regel"
    else
      echo "   ✗ ONVERWACHT: $regel"
      fout=1
    fi
  done <<< "$verschil"
  [[ -z "$verschil" ]] && echo "   ✓ geen bestand bij of af"
  if [[ $fout -ne 0 ]]; then
    echo "   ✗ DE LIJST IS ANDERS VERANDERD DAN VERWACHT — controleer handmatig!"
    return 1
  fi
  return 0
}

RC=0
MODUS="${1:-deploy}"

case "$MODUS" in
  --verify)
    verify
    exit $RC
    ;;
  --rollback)
    LAATSTE=$(ssh_ "ls -1d $BACKUPMAP/*/ 2>/dev/null | sort | tail -1")
    [[ -n "$LAATSTE" ]] || { echo "Geen backup gevonden in $BACKUPMAP."; exit 1; }
    NIEUW=$(ssh_ "cat ${LAATSTE}NIEUW.txt 2>/dev/null || true")
    echo "ROLLBACK uit $LAATSTE"
    echo "  terugzetten: $(ssh_ "ls -1 $LAATSTE | grep -v '^NIEUW.txt$' | tr '\n' ' '")"
    echo "  verwijderen (waren nieuw): ${NIEUW:-niets}"
    read -r -p "Doorgaan? (y/N) " antwoord
    [[ "$antwoord" == "y" ]] || { echo "Afgebroken."; exit 1; }
    ssh_ "ls -1 $DOELMAP" > "$VOOR"
    # Eerst de hooks die de nieuwe hulp gebruiken terugzetten, dan pas de
    # nieuwe bestanden weg.
    for b in $(ssh_ "ls -1 $LAATSTE | grep -v '^NIEUW.txt$'"); do
      ssh_ "cp ${LAATSTE}$b $DOELMAP/$b && chmod 644 $DOELMAP/$b"
      echo "   ✓ terug: $b"
    done
    for b in $NIEUW; do
      ssh_ "rm -f $DOELMAP/$b"
      echo "   ✓ weg: $b"
    done
    sleep 4
    ssh_ "ls -1 $DOELMAP" > "$NA"
    lijst_klopt "$NIEUW" || RC=1
    verify
    exit $RC
    ;;
  deploy) ;;
  *)
    echo "Onbekende optie: $MODUS"; exit 2
    ;;
esac

echo "1. node --check"
for b in "${BESTANDEN[@]}"; do
  node --check "$BRONMAP/$b"
  echo "   ✓ $b"
done

echo
echo "2. Lijst $DOELMAP VÓÓR de kopie"
ssh_ "ls -1 $DOELMAP" | tee "$VOOR" | sed 's/^/   /'
NIEUWE=()
for b in "${BESTANDEN[@]}"; do
  if grep -qx "$b" "$VOOR"; then
    echo "   = bestaat al: $b"
  else
    echo "   + NIEUW: $b"
    NIEUWE+=("$b")
  fi
done

echo
echo "2b. Verschil serverversie -> lokaal (alleen bestaande bestanden)"
for b in "${BESTANDEN[@]}"; do
  if [[ " ${NIEUWE[*]-} " == *" $b "* ]]; then
    echo "   --- $b: nieuw, $(wc -l < "$BRONMAP/$b" | tr -d ' ') regels"
    continue
  fi
  echo "   --- $b"
  ssh_ "cat $DOELMAP/$b" | diff - "$BRONMAP/$b" | sed 's/^/     /' || true
done

echo
read -r -p "3. ${BESTANDEN[*]} op $HOST:$DOELMAP/ zetten? (y/N) " antwoord
[[ "$antwoord" == "y" ]] || { echo "Afgebroken. Niets gewijzigd."; exit 1; }

TIJD=$(date -u +%Y-%m-%dT%H-%M-%S)
echo "4. backup naar $BACKUPMAP/$TIJD/, dan scp naar /tmp/ en cp naar $DOELMAP/"
ssh_ "mkdir -p $BACKUPMAP/$TIJD && printf '%s\n' ${NIEUWE[*]-} > $BACKUPMAP/$TIJD/NIEUW.txt"
for b in "${BESTANDEN[@]}"; do
  if [[ " ${NIEUWE[*]-} " != *" $b "* ]]; then
    ssh_ "cp $DOELMAP/$b $BACKUPMAP/$TIJD/$b"
  fi
  scp -q -i "$SLEUTEL" "$BRONMAP/$b" "$HOST:/tmp/$b" < /dev/null
  ssh_ "cp /tmp/$b $DOELMAP/$b && rm -f /tmp/$b && chmod 644 $DOELMAP/$b"
  echo "   ✓ $b"
done
echo "   (geen restart; PocketBase herlaadt zelf)"
sleep 4

echo
echo "6. Lijst $DOELMAP NA de kopie"
ssh_ "ls -1 $DOELMAP" | tee "$NA" | sed 's/^/   /'
lijst_klopt "${NIEUWE[*]-}" || RC=1

verify
exit $RC
