#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
#  ALIVE — Auto Epoch Runner
#  Continuously advances epochs: mine blocks → feed → simulate XCM returns
#  → harvest → evolve → allocate
#
#  Now uses MockXCM.simulateReturns() instead of minting tokens directly,
#  which creates realistic cross-chain capital flow:
#    1. FEED: Creatures deploy capital via XCM (tokens actually leave)
#    2. SIMULATE: MockXCM returns capital + yield (tokens come back)
#    3. HARVEST: Creatures measure real balance changes
#    4. EVOLVE: Evolution engine scores fitness (real data!)
#    5. ALLOCATE: Capital redistributed by fitness-weighted allocation
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
ECOSYSTEM="${ECOSYSTEM_ADDRESS:-0x0165878A594ca255338adfa4d48449f69242Eb8F}"
STABLECOIN="${STABLECOIN_ADDRESS:-0x5FbDB2315678afecb367f032d93F642f64180aa3}"
XCM="${XCM_ADDRESS:-0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0}"
EPOCH_BLOCKS=100  # epochDuration in the contract
YIELD_BPS_MIN=200   # 2% minimum yield per epoch
YIELD_BPS_MAX=800   # 8% maximum yield per epoch
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

# ── Simulate XCM yield returns ────────────────────────────────────
simulate_xcm_returns() {
  # Random yield between YIELD_BPS_MIN and YIELD_BPS_MAX
  local yield_bps=$(( RANDOM % (YIELD_BPS_MAX - YIELD_BPS_MIN) + YIELD_BPS_MIN ))
  
  # Check if there are outstanding deployments
  local dep_count
  dep_count=$(cast call "$XCM" "deploymentCount()(uint256)" --rpc-url "$RPC" 2>/dev/null | head -1 | tr -d ' ')
  
  if [[ "$dep_count" == "0" ]]; then
    ok "No outstanding deployments to return"
    return
  fi

  # Call MockXCM.simulateReturns(yieldBps) — returns all deployed capital + yield
  if quiet_send "$XCM" "simulateReturns(uint256)" "$yield_bps"; then
    local yield_pct=$(echo "scale=1; $yield_bps / 100" | bc 2>/dev/null || echo "$yield_bps bps")
    ok "XCM returned capital + ${yield_pct}% yield for $dep_count deployments"
  else
    err "MockXCM.simulateReturns failed"
  fi
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

  # Get creatures for reporting
  local creatures
  creatures=($(get_creatures))
  local count=${#creatures[@]}
  log "Active creatures: $count"

  # Phase 1: IDLE → FEEDING (includes _feedAll — creatures deploy capital via XCM)
  log "Phase 1: FEEDING (creatures deploy capital via XCM)..."
  if quiet_send "$ECOSYSTEM" "advanceEpoch()"; then
    ok "FEEDING complete — capital deployed to parachains"
  else
    err "FEEDING failed"
    return 1
  fi

  # Simulate XCM returns BEFORE harvest (capital + yield returns from parachains)
  log "Simulating cross-chain DeFi returns..."
  simulate_xcm_returns

  # Phase 2: HARVESTING (creatures measure real returns)
  log "Phase 2: HARVESTING (creatures measure returns)..."
  if quiet_send "$ECOSYSTEM" "advanceEpoch()"; then
    ok "HARVESTING complete"
  else
    err "HARVESTING failed"
    return 1
  fi

  # Phase 3: EVOLVING (fitness scoring, selection, breeding, killing)
  log "Phase 3: EVOLVING (fitness scoring + natural selection)..."
  if quiet_send "$ECOSYSTEM" "advanceEpoch()"; then
    ok "EVOLVING complete"
  else
    err "EVOLVING failed"
    return 1
  fi

  # Phase 4: ALLOCATING (fitness-weighted capital redistribution)
  log "Phase 4: ALLOCATING (fitness-weighted redistribution)..."
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
  local creature_count=$(echo "$state" | sed -n '3p' | tr -d ' []' | awk '{print $1}')
  local yield_raw=$(echo "$state" | sed -n '4p' | tr -d ' []' | awk '{print $1}')
  
  log "═══ Epoch $epoch complete ═══"
  ok "Total system value: \$$total_usd"
  ok "Active creatures: $creature_count"
  ok "Total yield generated: $yield_raw"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────
echo ""
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║   🧬 ALIVE — Auto Epoch Runner            ║"
echo "  ║   Ecosystem: ${ECOSYSTEM:0:10}...         ║"
echo "  ║   XCM:       ${XCM:0:10}...               ║"
echo "  ║   Interval:  ${INTERVAL}s                         ║"
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
