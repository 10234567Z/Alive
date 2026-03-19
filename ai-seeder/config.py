"""ALIVE AI Seeder – configuration & constants."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from dotenv import load_dotenv

load_dotenv()

# ── DNA field ranges (must match pvm/src/types.rs DnaFieldRanges) ────

DNA_FIELD_RANGES: dict[str, tuple[int, int]] = {
    "targetChainId":      (0, 5),
    "poolType":           (0, 5),
    "allocationRatio":    (1000, 10000),
    "rebalanceThreshold": (100, 5000),
    "maxSlippage":        (10, 1000),
    "yieldFloor":         (0, 5000),
    "riskCeiling":        (1, 10),
    "entryTiming":        (0, 5),
    "exitTiming":         (0, 5),
    "hedgeRatio":         (0, 5000),
}

POOL_TYPE_NAMES: dict[int, str] = {
    0: "AMM_LP",
    1: "LENDING",
    2: "STAKING",
    3: "VAULT",
    4: "STABLE_SWAP",
    5: "RESTAKING",
}

# ── Known Polkadot parachains ─────────────────────────────────────────

PARACHAIN_NAMES: dict[int, str] = {
    0: "Asset Hub",
    1: "Moonbeam",
    2: "Acala",
    3: "Astar",
    4: "HydraDX",
    5: "Bifrost",
}


@dataclass
class Config:
    """Runtime configuration loaded from environment."""

    rpc_url: str = field(default_factory=lambda: os.getenv("POLKADOT_HUB_RPC", ""))
    ecosystem_address: str = field(default_factory=lambda: os.getenv("ECOSYSTEM_ADDRESS", ""))
    genepool_address: str = field(default_factory=lambda: os.getenv("GENEPOOL_ADDRESS", ""))
    private_key: str = field(default_factory=lambda: os.getenv("SEEDER_PRIVATE_KEY", ""))

    google_api_key: str = field(default_factory=lambda: os.getenv("GOOGLE_API_KEY", ""))
    gemini_model: str = field(default_factory=lambda: os.getenv("GEMINI_MODEL", "gemini-2.5-flash-preview-05-20"))

    poll_interval: int = field(
        default_factory=lambda: int(os.getenv("POLL_INTERVAL_SECONDS", "120"))
    )
    min_diversity: float = field(
        default_factory=lambda: float(os.getenv("MIN_DIVERSITY_INDEX", "0.3"))
    )
    min_population: int = field(
        default_factory=lambda: int(os.getenv("MIN_POPULATION", "3"))
    )
    seeds_per_injection: int = field(
        default_factory=lambda: int(os.getenv("SEEDS_PER_INJECTION", "5"))
    )

    def validate(self) -> None:
        missing = []
        if not self.rpc_url:
            missing.append("POLKADOT_HUB_RPC")
        if not self.ecosystem_address:
            missing.append("ECOSYSTEM_ADDRESS")
        if not self.genepool_address:
            missing.append("GENEPOOL_ADDRESS")
        if not self.private_key:
            missing.append("SEEDER_PRIVATE_KEY")
        if not self.google_api_key:
            missing.append("GOOGLE_API_KEY")
        if missing:
            raise EnvironmentError(
                f"Missing required env vars: {', '.join(missing)}"
            )
