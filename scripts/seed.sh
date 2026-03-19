#!/usr/bin/env bash
# ============================================================
# ALIVE Protocol — Seed initial Creatures via AI Seeder
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOYMENTS_DIR="$ROOT_DIR/deployments"
SEEDER_DIR="$ROOT_DIR/ai-seeder"

# ---- Check deployment exists ----
DEPLOY_FILE="${DEPLOY_FILE:-$DEPLOYMENTS_DIR/polkadot-hub-testnet.json}"
if [[ ! -f "$DEPLOY_FILE" ]]; then
  echo "ERROR: Deployment file not found: $DEPLOY_FILE"
  echo "  Run scripts/deploy.sh first."
  exit 1
fi

# ---- Check env vars ----
if [[ -z "${PRIVATE_KEY:-}" ]]; then
  echo "ERROR: Set PRIVATE_KEY env var."
  exit 1
fi

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "ERROR: Set OPENAI_API_KEY env var for AI Seeder."
  exit 1
fi

# ---- Extract addresses ----
RPC_URL=$(python3 -c "import json; d=json.load(open('$DEPLOY_FILE')); print(d['rpc'])")
FACTORY=$(python3 -c "import json; d=json.load(open('$DEPLOY_FILE')); print(d['contracts']['CreatureFactory'])")
GENE_POOL=$(python3 -c "import json; d=json.load(open('$DEPLOY_FILE')); print(d['contracts']['GenePool'])")

echo "╔═══════════════════════════════════════════╗"
echo "║   ALIVE Protocol — AI Creature Seeding    ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "RPC:            $RPC_URL"
echo "Factory:        $FACTORY"
echo "GenePool:       $GENE_POOL"
echo ""

NUM_CREATURES="${NUM_CREATURES:-10}"
echo ">>> Seeding $NUM_CREATURES creatures..."

# ---- Activate venv & run seeder ----
cd "$SEEDER_DIR"

if [[ -d ".venv" ]]; then
  source .venv/bin/activate
fi

python3 -c "
import os, sys
sys.path.insert(0, '.')

os.environ['WEB3_RPC'] = '$RPC_URL'
os.environ['FACTORY_ADDRESS'] = '$FACTORY'
os.environ['GENE_POOL_ADDRESS'] = '$GENE_POOL'

from seeder import ALIVESeeder

seeder = ALIVESeeder()
seeder.run(num_creatures=$NUM_CREATURES)
"

echo ""
echo "=== Seeding Complete ==="
