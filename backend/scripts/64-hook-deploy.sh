#!/usr/bin/env bash
# HeitjeHulp M14 (lokaal na de cloud-PR) — werkt twee BESTAANDE hooks bij op
# de gedeelde PocketBase-server (root@178.104.171.224, map /root/pb_hooks/):
#   hh_klussen.pb.js      annuleren: de coordinator telt als de oudere
#   hh_coordinator.pb.js  koppelen: weigert een jongere met verlopen VOG
#
# Verschil met 63: deze bestanden staan al LIVE. Daarom eerst een backup van
# de serverversie naar /root/hh_hook_backups/<tijd>/ (buiten pb_hooks, dus
# niet geladen). --rollback zet de laatste backup terug.
#   1. node --check lokaal (syntax)
#   2. lijst /root/pb_hooks/ VÓÓR de kopie
#   3. bevestiging (y)
#   4. backup op de server, dan via /tmp/ naar /root/pb_hooks/
#   5. GEEN systemctl restart: PocketBase herlaadt hooks bij een wijziging
#   6. lijst NA de kopie; er mag geen bestand bij of af
#   7. verify: journalctl -n 20 (let op laadfouten). Het echte bewijs is
#      14-statuscheck (85), 50-koppelcheck (60) en 62-beheercheck.
#
#   ./64-hook-deploy.sh            deployen
#   ./64-hook-deploy.sh --rollback laatste backup terugzetten
#   ./64-hook-deploy.sh --verify   alleen stap 7
set -euo pipefail

HOST="root@178.104.171.224"
SLEUTEL="$HOME/.ssh/id_ed25519"
DOELMAP="/root/pb_hooks"
BACKUPMAP="/root/hh_hook_backups"
BESTANDEN=("hh_klussen.pb.js" "hh_coordinator.pb.js")
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRONMAP="$HIER/../pb_hooks"

ssh_() { ssh -i "$SLEUTEL" -o BatchMode=yes -o ConnectTimeout=10 "$HOST" "$@"; }

verify() {
  echo
  echo "VERIFY: journalctl -u pocketbase.service -n 20 (let op fouten)"
  ssh_ "journalctl -u pocketbase.service -n 20 --no-pager" | sed 's/^/  /'
  echo
  echo "  Bewijs: 14-statuscheck (85), 50-koppelcheck (60), 62-beheercheck"
}

lijst_gelijk() {
  local verschil
  verschil=$(diff /tmp/hh_hooks_voor_64.txt /tmp/hh_hooks_na_64.txt || true)
  if [[ -z "$verschil" ]]; then
    echo "   ✓ geen bestand bij of af"
    return 0
  fi
  echo "$verschil" | sed 's/^/   /'
  echo "   ✗ DE LIJST IS VERANDERD — controleer handmatig!"
  return 1
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
    echo "ROLLBACK: ${BESTANDEN[*]} terugzetten uit $LAATSTE"
    read -r -p "Doorgaan? (y/N) " antwoord
    [[ "$antwoord" == "y" ]] || { echo "Afgebroken."; exit 1; }
    ssh_ "ls -1 $DOELMAP" > /tmp/hh_hooks_voor_64.txt
    for b in "${BESTANDEN[@]}"; do
      ssh_ "cp ${LAATSTE}$b $DOELMAP/$b && chmod 644 $DOELMAP/$b"
      echo "   ✓ $b"
    done
    sleep 4
    ssh_ "ls -1 $DOELMAP" > /tmp/hh_hooks_na_64.txt
    lijst_gelijk || RC=1
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
ssh_ "ls -1 $DOELMAP" | tee /tmp/hh_hooks_voor_64.txt | sed 's/^/   /'
for b in "${BESTANDEN[@]}"; do
  grep -qx "$b" /tmp/hh_hooks_voor_64.txt || { echo "   ✗ $b staat niet op de server; dit script werkt alleen bestaande hooks bij."; exit 1; }
done

echo
read -r -p "3. ${BESTANDEN[*]} bijwerken op $HOST:$DOELMAP/? (y/N) " antwoord
[[ "$antwoord" == "y" ]] || { echo "Afgebroken. Niets gewijzigd."; exit 1; }

TIJD=$(date -u +%Y-%m-%dT%H-%M-%S)
echo "4. backup naar $BACKUPMAP/$TIJD/, dan scp naar /tmp/ en cp naar $DOELMAP/"
ssh_ "mkdir -p $BACKUPMAP/$TIJD"
for b in "${BESTANDEN[@]}"; do
  ssh_ "cp $DOELMAP/$b $BACKUPMAP/$TIJD/$b"
  scp -q -i "$SLEUTEL" "$BRONMAP/$b" "$HOST:/tmp/$b"
  ssh_ "cp /tmp/$b $DOELMAP/$b && rm -f /tmp/$b && chmod 644 $DOELMAP/$b"
  echo "   ✓ $b (backup: $BACKUPMAP/$TIJD/$b)"
done
echo "   (geen restart; PocketBase herlaadt zelf)"
sleep 4

echo
echo "6. Lijst $DOELMAP NA de kopie"
ssh_ "ls -1 $DOELMAP" | tee /tmp/hh_hooks_na_64.txt | sed 's/^/   /'
lijst_gelijk || RC=1

verify
exit $RC
