#!/usr/bin/env python3
"""ALIVE AI Seeder – main loop.

Monitors the on-chain ecosystem and injects new Creature DNA when the
population's genetic diversity drops below a threshold or the creature
count is too low.

Usage:
    python seeder.py              # run with LLM-based DNA generation
    python seeder.py --no-llm     # run with deterministic fallback
    python seeder.py --once       # single check + inject, then exit
"""

from __future__ import annotations

import argparse
import logging
import sys
import time

from config import Config
from market_scanner import scan
from dna_generator import generate_dna, generate_dna_deterministic
from submitter import Submitter

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("seeder")


def should_inject(
    creature_count: int,
    diversity_index: float,
    config: Config,
) -> tuple[bool, str]:
    """Decide whether to inject new seeds.

    Returns (should_inject, reason).
    """
    if creature_count < config.min_population:
        return True, f"population too low ({creature_count} < {config.min_population})"
    if diversity_index < config.min_diversity:
        return True, f"diversity too low ({diversity_index:.2f} < {config.min_diversity})"
    return False, "population healthy"


def run_once(config: Config, submitter: Submitter, use_llm: bool = True) -> None:
    """Perform a single check-and-inject cycle."""

    # 1. Read ecosystem state
    try:
        state = submitter.get_ecosystem_state()
    except Exception as exc:
        logger.error("Failed to read ecosystem state: %s", exc)
        return

    creature_count = state["creatureCount"]
    current_epoch = state["currentEpoch"]
    logger.info(
        "Ecosystem: epoch=%d  creatures=%d  deposits=%d  phase=%d",
        current_epoch, creature_count, state["totalDeposits"], state["phase"],
    )

    # 2. Compute diversity
    try:
        diversity = submitter.compute_diversity_index()
    except Exception as exc:
        logger.error("Failed to compute diversity: %s", exc)
        diversity = 1.0  # assume healthy on error so we don't spam

    logger.info("Diversity index: %.3f", diversity)

    # 3. Decide
    inject, reason = should_inject(creature_count, diversity, config)
    if not inject:
        logger.info("No injection needed: %s", reason)
        return

    logger.info("Injection triggered: %s", reason)

    # 4. Scan market
    market_data = scan()
    logger.info("Market scan: %d yield sources found", len(market_data))

    # 5. Generate DNA
    if use_llm:
        population_dna = submitter.get_population_dna()
        dna_list = generate_dna(
            config,
            market_data,
            population_dna,
            count=config.seeds_per_injection,
        )
        # Fall back to deterministic if LLM returned nothing
        if not dna_list:
            logger.warning("LLM returned no valid DNA, using deterministic fallback")
            dna_list = generate_dna_deterministic(
                market_data, count=config.seeds_per_injection,
            )
    else:
        dna_list = generate_dna_deterministic(
            market_data, count=config.seeds_per_injection,
        )

    if not dna_list:
        logger.error("No DNA generated – aborting injection")
        return

    logger.info("Generated %d DNA configs, submitting on-chain…", len(dna_list))

    # 6. Submit
    tx_hashes = submitter.inject_seeds(dna_list)
    logger.info(
        "Injection complete: %d/%d succeeded  (epoch %d)",
        len(tx_hashes), len(dna_list), current_epoch,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="ALIVE AI Seeder")
    parser.add_argument(
        "--no-llm", action="store_true",
        help="Use deterministic DNA generation (no OpenAI API needed)",
    )
    parser.add_argument(
        "--once", action="store_true",
        help="Run a single check+inject cycle and exit",
    )
    args = parser.parse_args()

    config = Config()

    # Validate config (skip OpenAI key check when --no-llm)
    try:
        if args.no_llm:
            # Only need chain + wallet config
            missing = []
            if not config.rpc_url:
                missing.append("POLKADOT_HUB_RPC")
            if not config.ecosystem_address:
                missing.append("ECOSYSTEM_ADDRESS")
            if not config.genepool_address:
                missing.append("GENEPOOL_ADDRESS")
            if not config.private_key:
                missing.append("SEEDER_PRIVATE_KEY")
            if missing:
                raise EnvironmentError(f"Missing: {', '.join(missing)}")
        else:
            config.validate()
    except EnvironmentError as exc:
        logger.error("Configuration error: %s", exc)
        sys.exit(1)

    submitter = Submitter(config)
    use_llm = not args.no_llm

    if args.once:
        run_once(config, submitter, use_llm=use_llm)
        return

    # ── Main loop ───────────────────────────────────────────────────
    logger.info(
        "Starting seeder loop (poll every %ds, llm=%s)",
        config.poll_interval, use_llm,
    )

    while True:
        try:
            run_once(config, submitter, use_llm=use_llm)
        except KeyboardInterrupt:
            logger.info("Shutting down")
            break
        except Exception as exc:
            logger.exception("Unhandled error in seeder loop: %s", exc)

        time.sleep(config.poll_interval)


if __name__ == "__main__":
    main()
