#!/usr/bin/env bash
# HeitjeHulp M9 — zet de twee M9-bestanden op de gedeelde PocketBase-server
# (root@178.104.171.224, map /root/pb_hooks/):
#   hh_familie_hulp.js   de aanvraag, de limiet en de standaardrechten
#                        (gewoon .js, geen hook; met require() opgehaald)
#   hh_familie.pb.js     de route /api/hh/koppelingen/aanvragen en de hooks
#                        op hh_koppelingen
#
# Waarom een eigen script: 10-hook-deploy.sh kent alleen hh_klussen.pb.js en
# mag in ronde 5 niet gewijzigd worden. Zelfde opzet als M7's
# 23-hook-deploy.sh. De werkwijze:
#   1. node --check lokaal (syntax)
#   2. lijst /root/pb_hooks/ VÓÓR de kopie
#   3. bevestiging (y); een agent-run mag `yes | ./43-hook-deploy.sh` gebruiken
#   4. eerst naar /tmp/ op de server, dan cp naar /root/pb_hooks/
#      (nooit een ander bestand aanraken of verwijderen)
#   5. GEEN systemctl restart: PocketBase herlaadt hooks bij een wijziging
#   6. lijst NA de kopie; het enige verschil mogen onze twee bestanden zijn
#   7. verify: de route zonder auth moet 401 geven (niet 404), en
#      journalctl -n 20 zonder laadfouten. Het echte bewijs is
#      42-familiecheck.mjs --apply.
#
# VOORWAARDE: hh_koppelingen.status bestaat (40-familie-velden.mjs --apply).
#
#   ./43-hook-deploy.sh            deployen
#   ./43-hook-deploy.sh --rollback beide bestanden weer verwijderen
#   ./43-hook-deploy.sh --verify   alleen stap 7
set -euo pipefail

HOST="root@178.104.171.224"
SLEUTEL="$HOME/.ssh/id_ed25519"
DOELMAP="/root/pb_hooks"
BESTANDEN=("hh_familie_hulp.js" "hh_familie.pb.js")
ROUTE_URL="https://api.qawayahbase.com/api/hh/koppelingen/aanvragen"
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRONMAP="$HIER/../pb_hooks"

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
  echo
  echo "  Bewijs: node scripts/42-familiecheck.mjs --apply"
}

alleen_onze() {
  # Geeft 0 als het verschil alleen uit onze bestanden bestaat.
  local verschil="$1" teken="$2" regel naam ok
  while IFS= read -r regel; do
    [[ "$regel" =~ ^[\<\>] ]] || continue
    naam="${regel#? }"
    ok=0
    for b in "${BESTANDEN[@]}"; do
      [[ "$regel" == "$teken $b" ]] && ok=1
    done
    [[ $ok == 1 ]] || { echo "   ✗ onverwacht: $naam"; return 1; }
  done <<< "$verschil"
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
    echo "ROLLBACK: ${BESTANDEN[*]} verwijderen uit $DOELMAP op $HOST"
    ssh_ "ls -1 $DOELMAP" > /tmp/hh_hooks_voor.txt
    read -r -p "Doorgaan? (y/N) " antwoord
    [[ "$antwoord" == "y" ]] || { echo "Afgebroken."; exit 1; }
    for b in "${BESTANDEN[@]}"; do
      ssh_ "rm -f $DOELMAP/$b"
    done
    ssh_ "ls -1 $DOELMAP" > /tmp/hh_hooks_na.txt
    VERSCHIL=$(diff /tmp/hh_hooks_voor.txt /tmp/hh_hooks_na.txt || true)
    echo "Verschil (alleen '< ' met onze bestanden mag verschijnen):"
    echo "$VERSCHIL" | sed 's/^/   /'
    alleen_onze "$VERSCHIL" "<" || RC=1
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
ssh_ "ls -1 $DOELMAP" | tee /tmp/hh_hooks_voor.txt | sed 's/^/   /'

echo
read -r -p "3. ${BESTANDEN[*]} kopiëren naar $HOST:$DOELMAP/? (y/N) " antwoord
[[ "$antwoord" == "y" ]] || { echo "Afgebroken. Niets gewijzigd."; exit 1; }

echo "4. scp naar /tmp/ op de server, dan cp naar $DOELMAP/"
# Eerst de helper, dan de hook: de hook mag nooit geladen worden zonder de
# helper ernaast.
for b in "${BESTANDEN[@]}"; do
  scp -q -i "$SLEUTEL" "$BRONMAP/$b" "$HOST:/tmp/$b"
  ssh_ "cp /tmp/$b $DOELMAP/$b && rm -f /tmp/$b && chmod 644 $DOELMAP/$b"
  echo "   ✓ $b"
done
echo "   (geen restart; PocketBase herlaadt zelf)"
sleep 4

echo
echo "6. Lijst $DOELMAP NA de kopie"
ssh_ "ls -1 $DOELMAP" | tee /tmp/hh_hooks_na.txt | sed 's/^/   /'
VERSCHIL=$(diff /tmp/hh_hooks_voor.txt /tmp/hh_hooks_na.txt || true)
if [[ -z "$VERSCHIL" ]]; then
  echo "   (geen verschil: de bestanden bestonden al en zijn bijgewerkt)"
else
  echo "$VERSCHIL" | sed 's/^/   /'
  if alleen_onze "$VERSCHIL" ">"; then
    echo "   ✓ alleen onze bestanden zijn nieuw"
  else
    echo "   ✗ ER IS MEER VERANDERD DAN ONZE BESTANDEN — controleer handmatig!"
    RC=1
  fi
fi

verify
exit $RC
