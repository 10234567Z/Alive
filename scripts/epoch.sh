#!/usr/bin/env bash
# ============================================================
# ALIVE Protocol — Trigger Epoch (demo / manual advance)
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOYMENTS_DIR="$ROOT_DIR/deployments"

# ---- Check deployment exists ----
DEPLOY_FILE="${DEPLOY_FILE:-$DEPLOYMENTS_DIR/polkadot-hub-testnet.json}"
if [[ ! -f "$DEPLOY_FILE" ]]; then
  echo "ERROR: Deployment file not found: $DEPLOY_FILE"
  echo "  Run scripts/deploy.sh first."
  exit 1
fi

# ---- Check PRIVATE_KEY ----
if [[ -z "${PRIVATE_KEY:-}" ]]; then
  echo "ERROR: Set PRIVATE_KEY env var."
  exit 1
fi

# ---- Extract addresses ----
RPC_URL=$(python3 -c "import json; d=json.load(open('$DEPLOY_FILE')); print(d['rpc'])")
ECOSYSTEM=$(python3 -c "import json; d=json.load(open('$DEPLOY_FILE')); print(d['contracts']['Ecosystem'])")

echo "╔═══════════════════════════════════════════╗"
echo "║   ALIVE Protocol — Epoch Trigger          ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "RPC:       $RPC_URL"
echo "Ecosystem: $ECOSYSTEM"
echo ""

# ---- Ecosystem ABI (only advanceEpoch needed) ----
EPOCH_ABI='[{"inputs":[],"name":"advanceEpoch","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"currentEpoch","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"phase","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"}]'

# ---- Check current state ----
echo ">>> Current epoch state:"
CURRENT_EPOCH=$(cast call "$ECOSYSTEM" "currentEpoch()(uint256)" --rpc-url "$RPC_URL" 2>/dev/null || echo "?")
CURRENT_PHASE=$(cast call "$ECOSYSTEM" "phase()(uint8)" --rpc-url "$RPC_URL" 2>/dev/null || echo "?")
echo "   Epoch:  $CURRENT_EPOCH"
echo "   Phase:  $CURRENT_PHASE (0=IDLE, 1=FEEDING, 2=HARVESTING, 3=EVOLVING, 4=ALLOCATING)"
echo ""

# ---- Advance epoch ----
echo ">>> Calling advanceEpoch()..."
TX_HASH=$(cast send "$ECOSYSTEM" "advanceEpoch()" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('transactionHash','?'))")

echo "   TX: $TX_HASH"

# ---- Show new state ----
echo ""
echo ">>> New epoch state:"
NEW_EPOCH=$(cast call "$ECOSYSTEM" "currentEpoch()(uint256)" --rpc-url "$RPC_URL" 2>/dev/null || echo "?")
NEW_PHASE=$(cast call "$ECOSYSTEM" "phase()(uint8)" --rpc-url "$RPC_URL" 2>/dev/null || echo "?")
echo "   Epoch:  $NEW_EPOCH"
echo "   Phase:  $NEW_PHASE"
echo ""
echo "=== Epoch Advance Complete ==="
