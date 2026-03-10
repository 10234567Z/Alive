"""DNA generator – uses an LLM to propose novel Creature DNA.

The generator receives current market yield data and the existing
population's DNA, then asks the LLM to create diverse new DNA
configurations that explore underrepresented strategy spaces.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Sequence

from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage

from config import Config, DNA_FIELD_RANGES, POOL_TYPE_NAMES, PARACHAIN_NAMES
from market_scanner import YieldSource

logger = logging.getLogger(__name__)


# ── Prompt templates ────────────────────────────────────────────────

_SYSTEM_PROMPT = """\
You are the AI Seeder for ALIVE, an evolutionary DeFi ecosystem on Polkadot.
Your role is to generate novel Creature DNA configurations that will be
injected into the on-chain population to maintain genetic diversity and
explore new yield strategies.

Each Creature has 10 DNA fields that control its DeFi behaviour:
{schema}

Pool types: {pool_types}
Known parachains: {parachains}

RULES:
1. Every field MUST be an integer within its stated [min, max] range.
2. Prioritise DIVERSITY – avoid duplicating existing population strategies.
3. Consider the available yield sources when choosing targetChainId and poolType.
4. Higher-risk strategies (high allocationRatio, low hedgeRatio) should be
   balanced with conservative ones.
5. Return ONLY a JSON array of DNA objects. No commentary.
"""

_USER_PROMPT = """\
Current yield opportunities:
{market_data}

Existing population DNA ({pop_count} creatures):
{population_dna}

Generate {count} new diverse creature DNA configurations.
Return ONLY a JSON array of objects with these exact keys:
targetChainId, poolType, allocationRatio, rebalanceThreshold,
maxSlippage, yieldFloor, riskCeiling, entryTiming, exitTiming, hedgeRatio
"""


# ── Schema helper ───────────────────────────────────────────────────

def _schema_text() -> str:
    lines = []
    for field_name, (lo, hi) in DNA_FIELD_RANGES.items():
        lines.append(f"  {field_name}: integer [{lo}, {hi}]")
    return "\n".join(lines)


# ── Validation ──────────────────────────────────────────────────────

def validate_dna(dna: dict[str, Any]) -> dict[str, int] | None:
    """Validate and clamp a single DNA dict.  Returns None if invalid."""
    clean: dict[str, int] = {}
    for field_name, (lo, hi) in DNA_FIELD_RANGES.items():
        val = dna.get(field_name)
        if val is None:
            logger.warning("Missing field %s in LLM output, skipping DNA", field_name)
            return None
        try:
            val = int(val)
        except (TypeError, ValueError):
            logger.warning("Non-integer value for %s: %s", field_name, val)
            return None
        # Clamp to valid range
        val = max(lo, min(hi, val))
        clean[field_name] = val
    return clean


def dna_dict_to_tuple(dna: dict[str, int]) -> tuple[int, ...]:
    """Convert a validated DNA dict to a tuple matching the Solidity struct order."""
    return (
        dna["targetChainId"],
        dna["poolType"],
        dna["allocationRatio"],
        dna["rebalanceThreshold"],
        dna["maxSlippage"],
        dna["yieldFloor"],
        dna["riskCeiling"],
        dna["entryTiming"],
        dna["exitTiming"],
        dna["hedgeRatio"],
    )


# ── Generator ───────────────────────────────────────────────────────

def generate_dna(
    config: Config,
    market_data: Sequence[YieldSource],
    population_dna: list[dict[str, int]],
    count: int = 5,
) -> list[dict[str, int]]:
    """Call the LLM and return validated DNA dicts."""

    llm = ChatOpenAI(
        model=config.openai_model,
        api_key=config.openai_api_key,
        temperature=0.9,   # high creativity
        max_tokens=2048,
    )

    system = SystemMessage(content=_SYSTEM_PROMPT.format(
        schema=_schema_text(),
        pool_types=json.dumps(POOL_TYPE_NAMES),
        parachains=json.dumps(PARACHAIN_NAMES),
    ))

    market_json = json.dumps([s.to_dict() for s in market_data], indent=2)
    pop_json = json.dumps(population_dna, indent=2) if population_dna else "[]"

    user = HumanMessage(content=_USER_PROMPT.format(
        market_data=market_json,
        population_dna=pop_json,
        pop_count=len(population_dna),
        count=count,
    ))

    logger.info("Requesting %d DNA from LLM (%s)…", count, config.openai_model)

    response = llm.invoke([system, user])
    raw = response.content.strip()

    # Strip markdown code fences if present
    if raw.startswith("```"):
        lines = raw.split("\n")
        lines = [l for l in lines if not l.startswith("```")]
        raw = "\n".join(lines)

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        logger.error("LLM returned invalid JSON: %s", exc)
        return []

    if not isinstance(parsed, list):
        parsed = [parsed]

    results: list[dict[str, int]] = []
    for item in parsed:
        validated = validate_dna(item)
        if validated is not None:
            results.append(validated)

    logger.info("Generated %d valid DNA (requested %d)", len(results), count)
    return results


# ── Fallback: deterministic generator (no LLM needed) ──────────────

def generate_dna_deterministic(
    market_data: Sequence[YieldSource],
    count: int = 5,
) -> list[dict[str, int]]:
    """Generate DNA without an LLM — one per yield source, round-robin.

    Useful for testing / demo without API keys.
    """
    results: list[dict[str, int]] = []
    for i in range(count):
        source = market_data[i % len(market_data)]
        dna: dict[str, int] = {
            "targetChainId": source.chain_id % 256,
            "poolType": source.pool_type_id,
            "allocationRatio": min(10000, max(1000, 3000 + i * 1000)),
            "rebalanceThreshold": min(5000, max(100, 500 + i * 200)),
            "maxSlippage": min(1000, max(10, 50 + i * 30)),
            "yieldFloor": min(5000, max(0, source.current_apy // 2)),
            "riskCeiling": min(10, max(1, 3 + i % 5)),
            "entryTiming": i % 6,
            "exitTiming": (i + 2) % 6,
            "hedgeRatio": min(5000, max(0, 1000 + i * 500)),
        }
        results.append(dna)
    return results
