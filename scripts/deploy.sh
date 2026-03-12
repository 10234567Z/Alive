#!/usr/bin/env bash
# ============================================================
# ALIVE Protocol — Deploy to Polkadot Hub Testnet (Westend)
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTRACTS_DIR="$ROOT_DIR/contracts"
DEPLOYMENTS_DIR="$ROOT_DIR/deployments"

# ---- Default RPC for Westend Asset Hub (EVM) ----
RPC_URL="${RPC_URL:-https://westend-asset-hub-eth-rpc.polkadot.io}"

# ---- Check PRIVATE_KEY ----
if [[ -z "${PRIVATE_KEY:-}" ]]; then
  echo "ERROR: Set PRIVATE_KEY env var before running."
  echo "  export PRIVATE_KEY=0xYourPrivateKey"
  exit 1
fi

echo "╔═══════════════════════════════════════════╗"
echo "║   ALIVE Protocol — Contract Deployment    ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "RPC:      $RPC_URL"
echo "Deployer: $(cast wallet address "$PRIVATE_KEY" 2>/dev/null || echo '(cast not found)')"
echo ""

# ---- Deploy ----
cd "$CONTRACTS_DIR"

echo ">>> Building contracts..."
forge build --force

echo ""
echo ">>> Deploying..."
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --slow \
  -vvvv 2>&1 | tee /tmp/alive-deploy.log

# ---- Extract addresses from broadcast JSON ----
BROADCAST_DIR="$CONTRACTS_DIR/broadcast/Deploy.s.sol"
CHAIN_DIR=$(ls -t "$BROADCAST_DIR" 2>/dev/null | head -1)

if [[ -n "$CHAIN_DIR" ]]; then
  RUN_FILE="$BROADCAST_DIR/$CHAIN_DIR/run-latest.json"

  if [[ -f "$RUN_FILE" ]]; then
    mkdir -p "$DEPLOYMENTS_DIR"

    # Extract deployed addresses from the broadcast JSON
    echo ""
    echo ">>> Extracting deployment addresses..."

    python3 -c "
import json, sys

with open('$RUN_FILE') as f:
    data = json.load(f)

contracts = {}
for tx in data.get('transactions', []):
    if tx.get('transactionType') == 'CREATE':
        name = tx.get('contractName', 'Unknown')
        addr = tx.get('contractAddress', '')
        contracts[name] = addr

# Write deployments JSON
output = {
    'network': 'westend-asset-hub',
    'rpc': '$RPC_URL',
    'contracts': contracts
}

with open('$DEPLOYMENTS_DIR/westend.json', 'w') as f:
    json.dump(output, f, indent=2)

print()
print('=== Deployed Contract Addresses ===')
for name, addr in contracts.items():
    print(f'  {name}: {addr}')
print()
print(f'Saved to: $DEPLOYMENTS_DIR/westend.json')
"
  fi
fi

echo ""
echo "=== Deployment Complete ==="
