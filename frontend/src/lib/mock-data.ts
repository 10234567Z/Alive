import { Creature, EcosystemState, EpochRecord, Phase } from "./types";

// ── Deterministic pseudo-random for consistent demo data ──────

function seededRandom(seed: number) {
  let s = seed;
  return () => {
    s = (s * 16807 + 0) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

const rng = seededRandom(420);

function randInt(min: number, max: number): number {
  return Math.floor(rng() * (max - min + 1)) + min;
}

function randAddr(): string {
  let hex = "0x";
  for (let i = 0; i < 40; i++) {
    hex += "0123456789abcdef"[randInt(0, 15)];
  }
  return hex;
}

// ── Mock Creatures ────────────────────────────────────────────

const CHAIN_IDS = [2034, 2000, 2004, 2006, 2030];

function makeCreature(index: number): Creature {
  const chainId = CHAIN_IDS[index % CHAIN_IDS.length];
  const poolType = index % 6;
  const alive = index < 12; // first 12 alive, last 3 dead
  const generation = Math.floor(index / 4) + 1;
  const epochs = alive ? randInt(1, 18) : randInt(1, 5);
  const cumReturn = alive
    ? randInt(-200_000, 800_000)
    : randInt(-500_000, -100_000);

  return {
    address: randAddr(),
    dna: {
      targetChainId: chainId % 256,
      poolType,
      allocationRatio: randInt(1000, 10000),
      rebalanceThreshold: randInt(100, 5000),
      maxSlippage: randInt(10, 500),
      yieldFloor: randInt(0, 3000),
      riskCeiling: randInt(1, 10),
      entryTiming: randInt(0, 5),
      exitTiming: randInt(0, 5),
      hedgeRatio: randInt(0, 5000),
    },
    performance: {
      lastReturn: randInt(-100_000, 300_000),
      cumulativeReturn: cumReturn,
      epochsSurvived: epochs,
      maxDrawdown: -randInt(10_000, 400_000),
    },
    fitnessScore: alive ? randInt(30_000, 80_000) : randInt(1_000, 15_000),
    generation,
    parent1: index > 3 ? randAddr() : null,
    parent2: index > 3 ? randAddr() : null,
    isAlive: alive,
    balance: alive ? randInt(5_000, 50_000) * 1e6 : 0, // in 6-decimal stablecoin
    birthEpoch: randInt(1, 8),
  };
}

export const MOCK_CREATURES: Creature[] = Array.from({ length: 15 }, (_, i) =>
  makeCreature(i)
).sort((a, b) => b.fitnessScore - a.fitnessScore);

// ── Mock Ecosystem State ──────────────────────────────────────

export const MOCK_ECOSYSTEM: EcosystemState = {
  totalDeposits: 1_250_000_000_000, // 1.25M USDC (6 decimals)
  currentEpoch: 9,
  creatureCount: 12,
  yieldGenerated: 87_500_000_000, // 87.5K
  phase: Phase.IDLE,
};

// ── Mock Epoch History ────────────────────────────────────────

export const MOCK_EPOCHS: EpochRecord[] = [
  { epoch: 1, births: 5, deaths: 0, topFitness: 45_200, avgYield: 3.2, populationSize: 5 },
  { epoch: 2, births: 2, deaths: 1, topFitness: 52_100, avgYield: 4.8, populationSize: 6 },
  { epoch: 3, births: 3, deaths: 1, topFitness: 58_400, avgYield: 6.1, populationSize: 8 },
  { epoch: 4, births: 2, deaths: 2, topFitness: 61_300, avgYield: 5.5, populationSize: 8 },
  { epoch: 5, births: 4, deaths: 1, topFitness: 65_800, avgYield: 7.2, populationSize: 11 },
  { epoch: 6, births: 1, deaths: 2, topFitness: 68_200, avgYield: 8.1, populationSize: 10 },
  { epoch: 7, births: 3, deaths: 1, topFitness: 72_500, avgYield: 9.4, populationSize: 12 },
  { epoch: 8, births: 2, deaths: 3, topFitness: 75_100, avgYield: 8.8, populationSize: 11 },
  { epoch: 9, births: 3, deaths: 2, topFitness: 78_400, avgYield: 10.2, populationSize: 12 },
];

// ── User mock ─────────────────────────────────────────────────

export const MOCK_USER = {
  address: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18",
  deposited: 50_000_000_000, // 50K USDC
  shares: 48_750,
  shareValue: 51_250_000_000, // 51.25K (earned yield)
};
