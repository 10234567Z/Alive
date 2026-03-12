"""Transaction submitter – wallet management & on-chain calls.

Handles signing, nonce tracking, and gas estimation for seeding
new Creatures into the GenePool contract.
"""

from __future__ import annotations

import logging
from typing import Any

from web3 import Web3
from web3.middleware import ExtraDataToPOAMiddleware

from abi import ECOSYSTEM_ABI, CREATURE_ABI, GENEPOOL_ABI
from config import Config
from dna_generator import dna_dict_to_tuple

logger = logging.getLogger(__name__)


class Submitter:
    """Manages an Ethereum-compatible wallet and sends transactions."""

    def __init__(self, config: Config) -> None:
        self.config = config
        self.w3 = Web3(Web3.HTTPProvider(config.rpc_url))
        # PoA chains need the extra-data middleware
        self.w3.middleware_onion.inject(ExtraDataToPOAMiddleware, layer=0)

        self.account = self.w3.eth.account.from_key(config.private_key)
        self.address = self.account.address
        logger.info("Submitter initialised – wallet %s", self.address)

        self.ecosystem = self.w3.eth.contract(
            address=Web3.to_checksum_address(config.ecosystem_address),
            abi=ECOSYSTEM_ABI,
        )
        self.genepool = self.w3.eth.contract(
            address=Web3.to_checksum_address(config.genepool_address),
            abi=GENEPOOL_ABI,
        )

    # ── Read helpers ────────────────────────────────────────────────

    def get_ecosystem_state(self) -> dict[str, Any]:
        """Call Ecosystem.getEcosystemState() and return structured data."""
        result = self.ecosystem.functions.getEcosystemState().call()
        return {
            "totalDeposits": result[0],
            "currentEpoch": result[1],
            "creatureCount": result[2],
            "yieldGenerated": result[3],
            "phase": result[4],
        }

    def get_active_creatures(self) -> list[str]:
        """Return list of active Creature addresses."""
        return self.ecosystem.functions.getActiveCreatures().call()

    def get_creature_dna(self, creature_address: str) -> dict[str, int]:
        """Read a single Creature's DNA."""
        creature = self.w3.eth.contract(
            address=Web3.to_checksum_address(creature_address),
            abi=CREATURE_ABI,
        )
        dna = creature.functions.getDNA().call()
        return {
            "targetChainId": dna[0],
            "poolType": dna[1],
            "allocationRatio": dna[2],
            "rebalanceThreshold": dna[3],
            "maxSlippage": dna[4],
            "yieldFloor": dna[5],
            "riskCeiling": dna[6],
            "entryTiming": dna[7],
            "exitTiming": dna[8],
            "hedgeRatio": dna[9],
        }

    def get_population_dna(self) -> list[dict[str, int]]:
        """Read DNA of all active Creatures."""
        creatures = self.get_active_creatures()
        dna_list = []
        for addr in creatures:
            try:
                dna_list.append(self.get_creature_dna(addr))
            except Exception as exc:
                logger.warning("Failed to read DNA for %s: %s", addr, exc)
        return dna_list

    def get_current_epoch(self) -> int:
        """Return the current epoch number."""
        return self.ecosystem.functions.currentEpoch().call()

    # ── Write helpers ───────────────────────────────────────────────

    def inject_seed(self, dna_dict: dict[str, int]) -> str | None:
        """Submit a single injectSeed transaction.

        Returns the tx hash on success, None on failure.
        """
        dna_tuple = dna_dict_to_tuple(dna_dict)
        current_epoch = self.get_current_epoch()

        try:
            nonce = self.w3.eth.get_transaction_count(self.address)
            gas_price = self.w3.eth.gas_price
            tx = self.genepool.functions.injectSeed(
                dna_tuple,
                current_epoch,
            ).build_transaction({
                "from": self.address,
                "nonce": nonce,
                "gas": 2_000_000,
                "gasPrice": gas_price,
            })

            signed = self.account.sign_transaction(tx)
            tx_hash = self.w3.eth.send_raw_transaction(signed.raw_transaction)
            hex_hash = tx_hash.hex()
            logger.info("injectSeed tx sent: %s", hex_hash)

            receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
            if receipt["status"] == 1:
                logger.info("injectSeed confirmed in block %d", receipt["blockNumber"])
                return hex_hash
            else:
                logger.error("injectSeed reverted – tx %s", hex_hash)
                return None

        except Exception as exc:
            logger.error("injectSeed failed: %s", exc)
            return None

    def inject_seeds(self, dna_list: list[dict[str, int]]) -> list[str]:
        """Submit multiple seed injections sequentially.

        Returns list of successful tx hashes.
        """
        successes: list[str] = []
        for i, dna in enumerate(dna_list):
            logger.info("Injecting seed %d/%d …", i + 1, len(dna_list))
            tx_hash = self.inject_seed(dna)
            if tx_hash:
                successes.append(tx_hash)
        logger.info("Injected %d/%d seeds successfully", len(successes), len(dna_list))
        return successes

    # ── Diversity metric ────────────────────────────────────────────

    def compute_diversity_index(self) -> float:
        """Diversity = unique targetChainId values / population size.

        Returns 1.0 if population is empty (trigger injection).
        """
        population_dna = self.get_population_dna()
        if not population_dna:
            return 1.0
        unique_chains = len(set(d["targetChainId"] for d in population_dna))
        return unique_chains / len(population_dna)
