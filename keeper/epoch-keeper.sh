#!/usr/bin/env bash
# ── ALIVE Epoch Keeper ──────────────────────────────────────────
# Automatically advances epochs on the Ecosystem contract.
# Polls every few seconds, checks if an epoch can be advanced,
# and runs through all 4 phases automatically.
#
# Usage:
#   ./keeper/epoch-keeper.sh                    # defaults
#   POLL_INTERVAL=10 ./keeper/epoch-keeper.sh   # custom poll interval
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

RPC_URL="${RPC_URL:-https://eth-rpc-testnet.polkadot.io/}"
PRIVATE_KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
ECOSYSTEM="${ECOSYSTEM:-0xdf422894281A27Aa3d19B0B7D578c59Cb051ABF8}"
XCM_ROUTER="${XCM_ROUTER:-0xA36B5Fec0E93d24908fAA9966535567E9f888994}"
POLL_INTERVAL="${POLL_INTERVAL:-30}"  # seconds between checks
YIELD_BPS="${YIELD_BPS:-500}"  # 5% yield per epoch

# Phase enum: 0=IDLE, 1=FEEDING, 2=HARVESTING, 3=EVOLVING, 4=ALLOCATING
PHASE_NAMES=("IDLE" "FEEDING" "HARVESTING" "EVOLVING" "ALLOCATING")

log() {
  echo "[$(date '+%H:%M:%S')] $*"
}

get_phase() {
  cast call "$ECOSYSTEM" "phase()(uint8)" --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}'
}

get_epoch() {
  cast call "$ECOSYSTEM" "currentEpoch()(uint256)" --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}'
}

get_epoch_duration() {
  cast call "$ECOSYSTEM" "epochDuration()(uint256)" --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}'
}

get_last_epoch_block() {
  cast call "$ECOSYSTEM" "lastEpochBlock()(uint256)" --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}'
}

get_block_number() {
  cast block-number --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}'
}

advance() {
  local phase_name="${PHASE_NAMES[$1]:-UNKNOWN}"
  log "  ⚡ Advancing from $phase_name..."
  
  local result
  # If transitioning from HARVESTING, simulate returns first
  if [[ "$1" == "2" ]]; then
    log "  💰 Simulating XCM returns (${YIELD_BPS} bps)..."
    cast send "$XCM_ROUTER" "simulateReturns(uint256)" "$YIELD_BPS" \
      --rpc-url "$RPC_URL" \
      --private-key "$PRIVATE_KEY" \
      --chain polkadot-testnet \
      --json &>/dev/null || true
    sleep 2
  fi

  result=$(cast send "$ECOSYSTEM" "advanceEpoch()" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --chain polkadot-testnet \
    --json 2>&1)
  
  if echo "$result" | grep -q '"status":"0x1"'; then
    local new_phase
    new_phase=$(get_phase)
    log "  ✓ → ${PHASE_NAMES[$new_phase]:-UNKNOWN}"
    return 0
  else
    log "  ✗ Transaction failed"
    return 1
  fi
}

run_full_cycle() {
  local epoch
  epoch=$(get_epoch)
  log "═══ Starting epoch cycle (current epoch: $epoch) ═══"
  
  local phase
  phase=$(get_phase)
  
  # Run through all remaining phases until back to IDLE
  local max_steps=5  # safety limit
  local step=0
  
  while [[ "$phase" != "0" || $step -eq 0 ]]; do
    if ! advance "$phase"; then
      log "  Failed at phase ${PHASE_NAMES[$phase]:-$phase}, will retry next poll"
      return 1
    fi
    
    phase=$(get_phase)
    step=$((step + 1))
    
    if [[ $step -ge $max_steps ]]; then
      log "  Safety limit reached, breaking"
      break
    fi
    
    sleep 1  # brief pause between phase advances
  done
  
  local new_epoch
  new_epoch=$(get_epoch)
  log "═══ Epoch $new_epoch complete ═══"
}

# ── Main loop ──

log "╔══════════════════════════════════════════╗"
log "║     ALIVE Epoch Keeper — Running         ║"
log "╠══════════════════════════════════════════╣"
log "║  RPC:       $RPC_URL"
log "║  Ecosystem: $ECOSYSTEM"
log "║  Poll:      ${POLL_INTERVAL}s"
log "╚══════════════════════════════════════════╝"

# Verify connection
if ! cast chain-id --rpc-url "$RPC_URL" &>/dev/null; then
  log "✗ Cannot connect to $RPC_URL"
  exit 1
fi

log "Connected to chain $(cast chain-id --rpc-url "$RPC_URL")"

while true; do
  phase=$(get_phase 2>/dev/null || echo "ERR")
  
  if [[ "$phase" == "ERR" ]]; then
    log "⚠ Cannot read contract, retrying in ${POLL_INTERVAL}s..."
    sleep "$POLL_INTERVAL"
    continue
  fi
  
  if [[ "$phase" != "0" ]]; then
    # Mid-cycle — finish it
    log "Mid-cycle detected (phase=${PHASE_NAMES[$phase]:-$phase}), completing..."
    run_full_cycle
  else
    # IDLE — check if epoch duration has elapsed
    epoch_duration=$(get_epoch_duration)
    last_block=$(get_last_epoch_block)
    current_block=$(get_block_number)
    
    target=$((last_block + epoch_duration))
    remaining=$((target - current_block))
    
    if [[ $remaining -le 0 ]]; then
      run_full_cycle
    fi
  fi
  
  sleep "$POLL_INTERVAL"
done
