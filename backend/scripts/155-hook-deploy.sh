#!/usr/bin/env bash
# HeitjeHulp ID-AFKEUR (besluit Ibrahim 4 okt) — afkeuren wist het ID-document
# ook, net als goedkeuren. Zet op de gedeelde PocketBase-server
# (root@178.104.171.224, map /root/pb_hooks/):
#   GEWIJZIGD hh_beheer_hulp.js     + isAfkeuring()
#   GEWIJZIGD hh_aanmelden.pb.js    onRecordUpdate hh_profielen: bij de overgang
#                                   naar "afgewezen" document_foto leeg
#                                   (id_gecontroleerd_op blijft leeg)
# Stuurt ALLEEN deze twee bestanden mee. Geen velden, geen rules.
#
# Zoals 153 (patroon: ssh -n, backup, diff 2b, rollback):
#   1. node --check lokaal (syntax)
#   2. lijst /root/pb_hooks/ VOOR de kopie
#   2b. verschil serverversie -> lokaal. Verwacht: ALLEEN de ID-AFKEUR-regels.
#       Ziet u meer verschil, dan loopt prod niet gelijk met main: afbreken.
#   3. bevestiging (y)   (met auto-mode uit: `yes y | ./155-hook-deploy.sh`)
#   4. backup op de server naar /root/hh_hook_backups/id-afkeur/<tijd>/, dan
#      via /tmp/ naar /root/pb_hooks/ (hulp eerst)
#   5. GEEN systemctl restart: PocketBase herlaadt hooks bij een wijziging
#   6. lijst NA de kopie; er mag geen bestand bij of af
#   7. verify: journalctl -n 20 (let op laadfouten). Het echte bewijs is
#      72-b1check.mjs --apply (sectie F: "afwijzen wist document_foto ook").
#
#   ./155-hook-deploy.sh            deployen
#   ./155-hook-deploy.sh --rollback laatste backup terugzetten
#   ./155-hook-deploy.sh --verify   alleen stap 7

set -euo pipefail

HOST="root@178.104.171.224"
SLEUTEL="$HOME/.ssh/id_ed25519"
DOELMAP="/root/pb_hooks"
BACKUPMAP="/root/hh_hook_backups/id-afkeur"  # eigen submap: --rollback pakt nooit een andere backup
# Volgorde telt: hulpbestanden eerst.
BESTANDEN=("hh_beheer_hulp.js" "hh_aanmelden.pb.js")
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRONMAP="$HIER/../pb_hooks"
VOOR=/tmp/hh_hooks_voor_155.txt
NA=/tmp/hh_hooks_na_155.txt

ssh_() { ssh -n -i "$SLEUTEL" -o BatchMode=yes -o ConnectTimeout=10 "$HOST" "$@"; }

verify() {
  echo
  echo "VERIFY: journalctl -u pocketbase.service -n 20 (let op fouten)"
  ssh_ "journalctl -u pocketbase.service -n 20 --no-pager" | sed 's/^/  /'
  echo
  echo "  Bewijs: node scripts/72-b1check.mjs --apply"
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
