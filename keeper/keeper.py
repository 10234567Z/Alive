#!/usr/bin/env python3
"""ALIVE Epoch Keeper — Python version for cloud deployment.

Polls the Ecosystem contract and auto-advances through epoch phases.
Before advancing from HARVESTING, calls XCMRouter.simulateReturns()
to mock yield generation.

Env vars:
    POLKADOT_HUB_RPC        RPC endpoint
    KEEPER_PRIVATE_KEY       Wallet private key
    ECOSYSTEM_ADDRESS        Ecosystem contract
    XCM_ROUTER_ADDRESS       XCMRouter contract
    POLL_INTERVAL_SECONDS    Seconds between polls (default 30)
    YIELD_BPS                Simulated yield in bps (default 500 = 5%)
"""

from __future__ import annotations

import logging
import os
import sys
import time

from web3 import Web3
from web3.middleware import ExtraDataToPOAMiddleware
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("keeper")

# ── Phase enum ──────────────────────────────────────────────────────

PHASE_NAMES = {0: "IDLE", 1: "FEEDING", 2: "HARVESTING", 3: "EVOLVING", 4: "ALLOCATING"}

# ── Minimal ABIs ────────────────────────────────────────────────────

ECOSYSTEM_ABI = [
    {"name": "phase",          "type": "function", "stateMutability": "view", "inputs": [], "outputs": [{"type": "uint8"}]},
    {"name": "currentEpoch",   "type": "function", "stateMutability": "view", "inputs": [], "outputs": [{"type": "uint256"}]},
    {"name": "epochDuration",  "type": "function", "stateMutability": "view", "inputs": [], "outputs": [{"type": "uint256"}]},
    {"name": "lastEpochBlock", "type": "function", "stateMutability": "view", "inputs": [], "outputs": [{"type": "uint256"}]},
    {"name": "advanceEpoch",   "type": "function", "stateMutability": "nonpayable", "inputs": [], "outputs": []},
    {"name": "getEcosystemState", "type": "function", "stateMutability": "view", "inputs": [],
     "outputs": [
         {"name": "deposits", "type": "uint256"},
         {"name": "epoch", "type": "uint256"},
         {"name": "creatureCount", "type": "uint256"},
         {"name": "yieldGenerated", "type": "int256"},
         {"name": "currentPhase", "type": "uint8"},
     ]},
]

XCM_ROUTER_ABI = [
    {"name": "simulateReturns", "type": "function", "stateMutability": "nonpayable",
     "inputs": [{"name": "yieldBps", "type": "uint256"}], "outputs": []},
]


class Keeper:
    def __init__(self) -> None:
        rpc = os.getenv("POLKADOT_HUB_RPC", "https://eth-rpc-testnet.polkadot.io/")
        pk = os.getenv("KEEPER_PRIVATE_KEY", os.getenv("SEEDER_PRIVATE_KEY", ""))
        eco_addr = os.getenv("ECOSYSTEM_ADDRESS", "")
        xcm_addr = os.getenv("XCM_ROUTER_ADDRESS", "")

        if not pk or not eco_addr or not xcm_addr:
            log.error("Missing env: KEEPER_PRIVATE_KEY, ECOSYSTEM_ADDRESS, XCM_ROUTER_ADDRESS")
            sys.exit(1)

        self.poll = int(os.getenv("POLL_INTERVAL_SECONDS", "30"))
        self.yield_bps = int(os.getenv("YIELD_BPS", "500"))

        self.w3 = Web3(Web3.HTTPProvider(rpc))
        self.w3.middleware_onion.inject(ExtraDataToPOAMiddleware, layer=0)
        self.account = self.w3.eth.account.from_key(pk)

        self.ecosystem = self.w3.eth.contract(
            address=Web3.to_checksum_address(eco_addr), abi=ECOSYSTEM_ABI,
        )
        self.xcm_router = self.w3.eth.contract(
            address=Web3.to_checksum_address(xcm_addr), abi=XCM_ROUTER_ABI,
        )

        chain_id = self.w3.eth.chain_id
        log.info("╔══════════════════════════════════════════╗")
        log.info("║     ALIVE Epoch Keeper (Python)          ║")
        log.info("╠══════════════════════════════════════════╣")
        log.info("║  Chain:     %d", chain_id)
        log.info("║  Ecosystem: %s", eco_addr)
        log.info("║  XCMRouter: %s", xcm_addr)
        log.info("║  Wallet:    %s", self.account.address)
        log.info("║  Poll:      %ds", self.poll)
        log.info("║  Yield:     %d bps", self.yield_bps)
        log.info("╚══════════════════════════════════════════╝")

    def _send_tx(self, fn) -> bool:
        """Build, sign, send a contract function call. Returns True on success."""
        try:
            nonce = self.w3.eth.get_transaction_count(self.account.address)
            tx = fn.build_transaction({
                "from": self.account.address,
                "nonce": nonce,
                "gas": 3_000_000,
                "gasPrice": self.w3.eth.gas_price,
            })
            signed = self.account.sign_transaction(tx)
            tx_hash = self.w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
            return receipt["status"] == 1
        except Exception as exc:
            log.error("Tx failed: %s", exc)
            return False

    def get_phase(self) -> int:
        return self.ecosystem.functions.phase().call()

    def get_epoch(self) -> int:
        return self.ecosystem.functions.currentEpoch().call()

    def advance(self, phase: int) -> bool:
        name = PHASE_NAMES.get(phase, "UNKNOWN")
        log.info("  ⚡ Advancing from %s...", name)

        # Before leaving HARVESTING, simulate XCM yield returns
        if phase == 2:
            log.info("  💰 Simulating XCM returns (%d bps)...", self.yield_bps)
            self._send_tx(self.xcm_router.functions.simulateReturns(self.yield_bps))
            time.sleep(2)

        ok = self._send_tx(self.ecosystem.functions.advanceEpoch())
        if ok:
            new_phase = self.get_phase()
            log.info("  ✓ → %s", PHASE_NAMES.get(new_phase, "UNKNOWN"))
        else:
            log.error("  ✗ Transaction failed")
        return ok

    def run_full_cycle(self) -> None:
        epoch = self.get_epoch()
        log.info("═══ Starting epoch cycle (current epoch: %d) ═══", epoch)

        phase = self.get_phase()
        steps = 0
        while (phase != 0 or steps == 0) and steps < 6:
            if not self.advance(phase):
                log.warning("  Failed at phase %s, will retry next poll", PHASE_NAMES.get(phase))
                return
            phase = self.get_phase()
            steps += 1
            time.sleep(1)

        new_epoch = self.get_epoch()
        log.info("═══ Epoch %d complete ═══", new_epoch)

    def run(self) -> None:
        while True:
            try:
                phase = self.get_phase()
            except Exception:
                log.warning("⚠ Cannot read contract, retrying in %ds...", self.poll)
                time.sleep(self.poll)
                continue

            if phase != 0:
                log.info("Mid-cycle detected (phase=%s), completing...", PHASE_NAMES.get(phase))
                self.run_full_cycle()
            else:
                try:
                    duration = self.ecosystem.functions.epochDuration().call()
                    last_block = self.ecosystem.functions.lastEpochBlock().call()
                    current_block = self.w3.eth.block_number
                    remaining = (last_block + duration) - current_block
                    if remaining <= 0:
                        self.run_full_cycle()
                except Exception as exc:
                    log.warning("Error checking epoch timing: %s", exc)

            time.sleep(self.poll)


if __name__ == "__main__":
    Keeper().run()
