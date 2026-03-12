#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
#  ALIVE — Auto Epoch Runner
#  Continuously advances epochs: mine blocks → feed → harvest → evolve
#  → allocate, with simulated yield minted to creature contracts.
#
#  Usage:
#    ./scripts/epoch-runner.sh              # Run continuously (default 15s interval)
#    ./scripts/epoch-runner.sh --once       # Run one epoch cycle
#    INTERVAL=5 ./scripts/epoch-runner.sh   # Custom interval in seconds
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────
RPC="${RPC_URL:-http://localhost:8545}"
KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
ECOSYSTEM="${ECOSYSTEM_ADDRESS:-0x07882Ae1ecB7429a84f1D53048d35c4bB2056877}"
STABLECOIN="${STABLECOIN_ADDRESS:-0xF8e31cb472bc70500f08Cd84917E5A1912Ec8397}"
EPOCH_BLOCKS=100  # epochDuration in the contract
YIELD_MIN=50000000    # 50 USDC minimum yield per creature (6 decimals)
YIELD_MAX=200000000   # 200 USDC maximum yield per creature (6 decimals)
INTERVAL="${INTERVAL:-15}"  # seconds between epoch cycles
ONCE=false

# Parse args
for arg in "$@"; do
  case "$arg" in
    --once) ONCE=true ;;
  esac
done

# ── Helpers ─────────────────────────────────────────────────────────
log() { echo -e "\033[1;36m[$(date +%H:%M:%S)]\033[0m $*"; }
ok()  { echo -e "\033[1;32m  ✓\033[0m $*"; }
err() { echo -e "\033[1;31m  ✗\033[0m $*"; }

quiet_send() {
  local result
  result=$(cast send "$@" --private-key "$KEY" --rpc-url "$RPC" 2>&1)
  if echo "$result" | grep -q "status.*1"; then
    return 0
  else
    echo "$result" >&2
    return 1
  fi
}

# ── Get creature addresses ────────────────────────────────────────
get_creatures() {
  local count
  count=$(cast call "$ECOSYSTEM" "getCreatureCount()(uint256)" --rpc-url "$RPC" 2>/dev/null)
  count=$(echo "$count" | head -1 | tr -d ' ')
  
  local creatures=()
  for ((i=0; i<count; i++)); do
    local addr
    addr=$(cast call "$ECOSYSTEM" "activeCreatures(uint256)(address)" "$i" --rpc-url "$RPC" 2>/dev/null)
    addr=$(echo "$addr" | head -1 | tr -d ' ')
    creatures+=("$addr")
  done
  echo "${creatures[@]}"
}

# ── Mint simulated yield to creatures ─────────────────────────────
mint_yield() {
  local creatures=($@)
  local total_minted=0

  for creature in "${creatures[@]}"; do
    # Check if creature is alive
    local alive
    alive=$(cast call "$creature" "isAlive()(bool)" --rpc-url "$RPC" 2>/dev/null | head -1)
    if [[ "$alive" != "true" ]]; then
      continue
    fi

    # Random yield between YIELD_MIN and YIELD_MAX
    local yield_amount=$(( RANDOM % (YIELD_MAX - YIELD_MIN) + YIELD_MIN ))
    
    # Mint directly to creature contract (simulates DeFi yield)
    quiet_send "$STABLECOIN" "mint(address,uint256)" "$creature" "$yield_amount" 2>/dev/null && {
      total_minted=$((total_minted + yield_amount))
    }
  done

  local total_usd=$(echo "scale=2; $total_minted / 1000000" | bc 2>/dev/null || echo "$total_minted")
  ok "Minted \$${total_usd} simulated yield across ${#creatures[@]} creatures"
}

# ── Run one full epoch cycle ──────────────────────────────────────
run_epoch() {
  local epoch_num
  epoch_num=$(cast call "$ECOSYSTEM" "currentEpoch()(uint256)" --rpc-url "$RPC" 2>/dev/null | head -1)
  local next_epoch=$((epoch_num + 1))

  log "═══ Epoch $next_epoch starting ═══"

  # Mine enough blocks to pass epochDuration
  log "Mining $EPOCH_BLOCKS blocks..."
  cast rpc anvil_mine "$(printf '0x%x' $EPOCH_BLOCKS)" --rpc-url "$RPC" > /dev/null 2>&1
  ok "Mined $EPOCH_BLOCKS blocks"

  # Get creatures for yield simulation
  local creatures
  creatures=($(get_creatures))
  local count=${#creatures[@]}
  log "Active creatures: $count"

  # Phase 1: IDLE → FEEDING (includes _feedAll)
  log "Phase 1: FEEDING..."
  if quiet_send "$ECOSYSTEM" "advanceEpoch()"; then
    ok "FEEDING complete"
  else
    err "FEEDING failed"
    return 1
  fi

  # Mint simulated yield BEFORE harvest (so harvest sees the gains)
  log "Simulating DeFi yield..."
  mint_yield "${creatures[@]}"

  # Phase 2: HARVESTING
  log "Phase 2: HARVESTING..."
  if quiet_send "$ECOSYSTEM" "advanceEpoch()"; then
    ok "HARVESTING complete"
  else
    err "HARVESTING failed"
    return 1
  fi

  # Phase 3: EVOLVING
  log "Phase 3: EVOLVING..."
  if quiet_send "$ECOSYSTEM" "advanceEpoch()"; then
    ok "EVOLVING complete"
  else
    err "EVOLVING failed"
    return 1
  fi

  # Phase 4: ALLOCATING (recalls + redistributes capital)
  log "Phase 4: ALLOCATING..."
  if quiet_send "$ECOSYSTEM" "advanceEpoch()"; then
    ok "ALLOCATING complete"
  else
    err "ALLOCATING failed"
    return 1
  fi

  # ── Report ──
  local state
  state=$(cast call "$ECOSYSTEM" "getEcosystemState()(uint256,uint256,uint256,int256,uint8)" --rpc-url "$RPC" 2>/dev/null)
  
  local total_value=$(echo "$state" | head -1 | tr -d ' []' | awk '{print $1}')
  local total_usd=$(echo "scale=2; $total_value / 1000000" | bc 2>/dev/null || echo "$total_value")
  local epoch=$(echo "$state" | sed -n '2p' | tr -d ' []' | awk '{print $1}')
  local yield_raw=$(echo "$state" | sed -n '4p' | tr -d ' []' | awk '{print $1}')
  
  log "═══ Epoch $epoch complete ═══"
  ok "Total system value: \$$total_usd"
  ok "Total yield generated: $yield_raw wei"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────
echo ""
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║   🧬 ALIVE — Auto Epoch Runner            ║"
echo "  ║   Ecosystem: ${ECOSYSTEM:0:10}...         ║"
echo "  ║   Interval: ${INTERVAL}s                          ║"
echo "  ╚═══════════════════════════════════════════╝"
echo ""

if $ONCE; then
  run_epoch
else
  while true; do
    run_epoch
    log "Sleeping ${INTERVAL}s until next epoch..."
    sleep "$INTERVAL"
  done
fi
