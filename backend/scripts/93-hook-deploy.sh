#!/usr/bin/env bash
# HeitjeHulp B3 — zet de B3-hooks op de gedeelde PocketBase-server
# (root@178.104.171.224, map /root/pb_hooks/):
#   NIEUW  hh_ouder_hulp.js   rekenwerk + mailteksten ouder-toestemming
#   NIEUW  hh_ouder.pb.js     routes /api/hh/ouder/{versturen,status,code,
#                             toestemming,intrekken}
# Verder NIETS: hh_aanmelden_hulp.js (gebruikt door hh_ouder.pb.js) staat er
# sinds B2 al ongewijzigd. hh_familie.pb.js en hh_familie_hulp.js (K5) gaan
# NIET meer mee met een deploy, maar dit script haalt ze ook NIET van de
# server: opruimen op prod is een aparte beslissing.
#
# VOORWAARDE: 90-b3-collectie.mjs --apply (de routes schrijven in
# hh_ouder_toestemming). Mail gaat via de bestaande SMTP-instelling van de
# server; dit script verandert geen instelling.
#
# Zoals 83 (ssh -n, nieuwe bestanden mogen, --rollback verwijdert ze weer):
#   1. node --check lokaal (syntax)
#   2. lijst /root/pb_hooks/ VOOR de kopie
#   2b. verschil serverversie -> lokaal per bestaand bestand (hier: beide
#       bestanden zijn nieuw, dus alleen de regeltelling)
#   3. bevestiging (y)
#   4. backup op de server naar /root/hh_hook_backups/b3/<tijd>/ (plus
#      NIEUW.txt), dan via /tmp/ naar /root/pb_hooks/ (hulp eerst)
#   5. GEEN systemctl restart: PocketBase herlaadt hooks bij een wijziging
#   6. lijst NA de kopie; alleen de nieuwe bestanden mogen erbij
#   7. verify: journalctl -n 20 (let op laadfouten). Het echte bewijs is
#      92-b3check.mjs --apply.
#
#   ./93-hook-deploy.sh            deployen
#   ./93-hook-deploy.sh --rollback laatste backup terugzetten (haalt de 2
#                                  nieuwe bestanden weer weg)
#   ./93-hook-deploy.sh --verify   alleen stap 7
set -euo pipefail

HOST="root@178.104.171.224"
SLEUTEL="$HOME/.ssh/id_ed25519"
DOELMAP="/root/pb_hooks"
BACKUPMAP="/root/hh_hook_backups/b3"  # eigen submap: --rollback pakt nooit een backup van 73/83
# Volgorde telt: hulpbestanden eerst.
BESTANDEN=("hh_ouder_hulp.js" "hh_ouder.pb.js")
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRONMAP="$HIER/../pb_hooks"
VOOR=/tmp/hh_hooks_voor_93.txt
NA=/tmp/hh_hooks_na_93.txt

ssh_() { ssh -n -i "$SLEUTEL" -o BatchMode=yes -o ConnectTimeout=10 "$HOST" "$@"; }

verify() {
  echo
  echo "VERIFY: journalctl -u pocketbase.service -n 20 (let op fouten)"
  ssh_ "journalctl -u pocketbase.service -n 20 --no-pager" | sed 's/^/  /'
  echo
  echo "  Bewijs: node scripts/92-b3check.mjs --apply (en 82, 72, 62, 04, 50)"
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

for b in "${BESTANDEN[@]}"; do
  [[ "$b" == hh_familie* ]] && { echo "hh_familie*.js gaat niet meer mee (K5)."; exit 2; }
done

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
