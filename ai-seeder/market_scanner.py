"""Market scanner – fetches yield data from Polkadot parachains.

For the hackathon MVP this module uses static / mock data so the
project works without live indexers.  The interface is designed so
that real data sources (Subsquid, parachain RPCs) can be plugged in
later by implementing additional ``fetch_*`` functions.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, asdict
from typing import Sequence

import httpx

from config import PARACHAIN_NAMES, POOL_TYPE_NAMES

logger = logging.getLogger(__name__)


# ── Data model ──────────────────────────────────────────────────────

@dataclass
class YieldSource:
    """A single yield opportunity on a Polkadot parachain."""

    chain_id: int
    chain_name: str
    pool_address: str
    pool_type: str       # one of POOL_TYPE_NAMES values
    pool_type_id: int    # numeric (matches DNA poolType field)
    current_apy: int     # basis points (e.g. 1240 = 12.40%)
    tvl_usd: int
    age_days: int
    token_pair: list[str]

    def to_dict(self) -> dict:
        return asdict(self)


# ── Static / mock sources (hackathon MVP) ───────────────────────────

_MOCK_SOURCES: list[YieldSource] = [
    YieldSource(
        chain_id=2034, chain_name="Hydration",
        pool_address="0xHYD_STABLE_001",
        pool_type="STABLE_SWAP", pool_type_id=4,
        current_apy=1240, tvl_usd=5_200_000, age_days=180,
        token_pair=["USDC", "USDT"],
    ),
    YieldSource(
        chain_id=2034, chain_name="Hydration",
        pool_address="0xHYD_AMM_002",
        pool_type="AMM_LP", pool_type_id=0,
        current_apy=2800, tvl_usd=1_800_000, age_days=90,
        token_pair=["DOT", "USDC"],
    ),
    YieldSource(
        chain_id=2000, chain_name="Acala",
        pool_address="0xACA_LENDING_001",
        pool_type="LENDING", pool_type_id=1,
        current_apy=850, tvl_usd=8_000_000, age_days=365,
        token_pair=["USDC"],
    ),
    YieldSource(
        chain_id=2000, chain_name="Acala",
        pool_address="0xACA_STAKING_001",
        pool_type="STAKING", pool_type_id=2,
        current_apy=1500, tvl_usd=12_000_000, age_days=300,
        token_pair=["DOT"],
    ),
    YieldSource(
        chain_id=2004, chain_name="Moonbeam",
        pool_address="0xMOON_VAULT_001",
        pool_type="VAULT", pool_type_id=3,
        current_apy=1900, tvl_usd=3_500_000, age_days=120,
        token_pair=["USDC", "GLMR"],
    ),
    YieldSource(
        chain_id=2004, chain_name="Moonbeam",
        pool_address="0xMOON_AMM_002",
        pool_type="AMM_LP", pool_type_id=0,
        current_apy=3200, tvl_usd=900_000, age_days=60,
        token_pair=["GLMR", "USDC"],
    ),
    YieldSource(
        chain_id=2006, chain_name="Astar",
        pool_address="0xASTAR_RESTAKE_001",
        pool_type="RESTAKING", pool_type_id=5,
        current_apy=2100, tvl_usd=2_200_000, age_days=45,
        token_pair=["ASTR"],
    ),
    YieldSource(
        chain_id=2030, chain_name="Bifrost",
        pool_address="0xBIF_STAKING_001",
        pool_type="STAKING", pool_type_id=2,
        current_apy=1100, tvl_usd=6_000_000, age_days=210,
        token_pair=["vDOT"],
    ),
]


def scan_mock() -> list[YieldSource]:
    """Return static mock yield sources for the hackathon demo."""
    return list(_MOCK_SOURCES)


# ── Live scanner (placeholder for production) ──────────────────────

async def scan_live(indexer_url: str | None = None) -> list[YieldSource]:
    """Fetch live yield data from Subsquid / parachain RPCs.

    Not implemented for the hackathon — falls back to mock data
    and logs a warning.
    """
    if indexer_url:
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.get(f"{indexer_url}/yield-sources")
                resp.raise_for_status()
                data = resp.json()
                return [
                    YieldSource(
                        chain_id=d["chain_id"],
                        chain_name=PARACHAIN_NAMES.get(d["chain_id"], f"chain-{d['chain_id']}"),
                        pool_address=d["pool_address"],
                        pool_type=POOL_TYPE_NAMES.get(d.get("pool_type_id", 0), "UNKNOWN"),
                        pool_type_id=d.get("pool_type_id", 0),
                        current_apy=d["current_apy"],
                        tvl_usd=d.get("tvl_usd", 0),
                        age_days=d.get("age_days", 0),
                        token_pair=d.get("token_pair", []),
                    )
                    for d in data
                ]
        except Exception as exc:
            logger.warning("Live scan failed (%s), falling back to mock data", exc)

    return scan_mock()


# ── Convenience ─────────────────────────────────────────────────────

def scan() -> list[YieldSource]:
    """Synchronous entry point – returns mock data for hackathon."""
    return scan_mock()
