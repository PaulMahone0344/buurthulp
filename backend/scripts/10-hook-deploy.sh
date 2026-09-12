#!/usr/bin/env bash
# HeitjeHulp M5 — zet backend/pb_hooks/hh_klussen.pb.js op de gedeelde
# PocketBase-server (root@178.104.171.224, map /root/pb_hooks/).
#
# Werkwijze (prompt M5, keuze 5):
#   1. node --check lokaal (syntax; de JSVM-globals zijn gewone identifiers)
#   2. lijst /root/pb_hooks/ VÓÓR de kopie
#   3. bevestiging (y) — de eigenaar heeft toestemming gegeven; een agent-run
#      mag `yes | ./10-hook-deploy.sh` gebruiken
#   4. eerst naar /tmp/ op de server, dan cp naar /root/pb_hooks/
#      (nooit een ander bestand aanraken of verwijderen)
#   5. GEEN systemctl restart: PocketBase herlaadt hooks bij een wijziging
#   6. lijst NA de kopie; het enige verschil mag ons bestand zijn
#   7. verify: route zonder auth -> 401/403 (niet 404); journalctl -n 20
#
#   ./10-hook-deploy.sh            deployen
#   ./10-hook-deploy.sh --rollback het bestand weer verwijderen uit /root/pb_hooks/
#   ./10-hook-deploy.sh --verify   alleen stap 7
set -euo pipefail

HOST="root@178.104.171.224"
SLEUTEL="$HOME/.ssh/id_ed25519"
DOELMAP="/root/pb_hooks"
BESTAND="hh_klussen.pb.js"
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOKAAL="$HIER/../pb_hooks/$BESTAND"
ROUTE_URL="https://api.qawayahbase.com/api/hh/klussen/deploycheck/accepteren"

ssh_() { ssh -i "$SLEUTEL" -o BatchMode=yes -o ConnectTimeout=10 "$HOST" "$@"; }

verify() {
  echo
  echo "VERIFY: route zonder auth (verwacht 401 of 403, NIET 404)"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$ROUTE_URL" || echo "000")
  echo "  POST $ROUTE_URL -> $code"
  if [[ "$code" == "401" || "$code" == "403" ]]; then
    echo "  ✓ route is geladen"
  else
    echo "  ✗ onverwachte status $code (404 = hook niet geladen)"
    RC=1
  fi
  echo
  echo "VERIFY: journalctl -u pocketbase.service -n 20 (let op fouten)"
  ssh_ "journalctl -u pocketbase.service -n 20 --no-pager" | sed 's/^/  /'
}

RC=0
MODUS="${1:-deploy}"

case "$MODUS" in
  --verify)
    verify
    exit $RC
    ;;
  --rollback)
    echo "ROLLBACK: $DOELMAP/$BESTAND verwijderen op $HOST"
    ssh_ "ls -1 $DOELMAP" > /tmp/hh_hooks_voor.txt
    read -r -p "Doorgaan? (y/N) " antwoord
    [[ "$antwoord" == "y" ]] || { echo "Afgebroken."; exit 1; }
    ssh_ "rm -f $DOELMAP/$BESTAND"
    ssh_ "ls -1 $DOELMAP" > /tmp/hh_hooks_na.txt
    echo "Verschil (alleen '< $BESTAND' mag verschijnen):"
    diff /tmp/hh_hooks_voor.txt /tmp/hh_hooks_na.txt || true
    sleep 3
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$ROUTE_URL" || echo "000")
    echo "Route na rollback -> $code (verwacht 404)"
    exit 0
    ;;
  deploy) ;;
  *)
    echo "Onbekende optie: $MODUS"; exit 2
    ;;
esac

echo "1. node --check $LOKAAL"
node --check "$LOKAAL"
echo "   ✓ syntax in orde"

echo
echo "2. Lijst $DOELMAP VÓÓR de kopie"
ssh_ "ls -1 $DOELMAP" | tee /tmp/hh_hooks_voor.txt | sed 's/^/   /'
AANTAL_VOOR=$(wc -l < /tmp/hh_hooks_voor.txt | tr -d ' ')
if grep -qx "$BESTAND" /tmp/hh_hooks_voor.txt; then
  echo "   (bestand staat er al; wordt overschreven)"
fi

echo
read -r -p "3. Kopiëren naar $HOST:$DOELMAP/$BESTAND? (y/N) " antwoord
[[ "$antwoord" == "y" ]] || { echo "Afgebroken. Niets gewijzigd."; exit 1; }

echo "4. scp naar /tmp/ op de server, dan cp naar $DOELMAP/"
scp -q -i "$SLEUTEL" "$LOKAAL" "$HOST:/tmp/$BESTAND"
ssh_ "cp /tmp/$BESTAND $DOELMAP/$BESTAND && rm -f /tmp/$BESTAND && chmod 644 $DOELMAP/$BESTAND"
echo "   ✓ gekopieerd (geen restart; PocketBase herlaadt zelf)"
sleep 4

echo
echo "6. Lijst $DOELMAP NA de kopie"
ssh_ "ls -1 $DOELMAP" | tee /tmp/hh_hooks_na.txt | sed 's/^/   /'
AANTAL_NA=$(wc -l < /tmp/hh_hooks_na.txt | tr -d ' ')
echo "   verschil vóór/na (alleen '> $BESTAND' is toegestaan):"
VERSCHIL=$(diff /tmp/hh_hooks_voor.txt /tmp/hh_hooks_na.txt || true)
if [[ -z "$VERSCHIL" ]]; then
  echo "   (geen verschil: bestand bestond al en is bijgewerkt)"
else
  echo "$VERSCHIL" | sed 's/^/   /'
  ANDERS=$(echo "$VERSCHIL" | grep '^[<>]' | grep -v "^> $BESTAND\$" || true)
  if [[ -n "$ANDERS" ]]; then
    echo "   ✗ ER IS MEER VERANDERD DAN ONS BESTAND — controleer handmatig!"
    RC=1
  else
    echo "   ✓ alleen $BESTAND is nieuw ($AANTAL_VOOR -> $AANTAL_NA bestanden)"
  fi
fi

verify
exit $RC
