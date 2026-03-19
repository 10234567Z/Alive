// ── ALIVE Frontend Types ──────────────────────────────────────

export interface CreatureDNA {
  targetChainId: number;
  poolType: number;
  allocationRatio: number;
  rebalanceThreshold: number;
  maxSlippage: number;
  yieldFloor: number;
  riskCeiling: number;
  entryTiming: number;
  exitTiming: number;
  hedgeRatio: number;
}

export interface CreaturePerformance {
  lastReturn: number;
  cumulativeReturn: number;
  epochsSurvived: number;
  maxDrawdown: number;
}

export interface Creature {
  address: string;
  dna: CreatureDNA;
  performance: CreaturePerformance;
  fitnessScore: number;
  generation: number;
  parent1: string | null;
  parent2: string | null;
  isAlive: boolean;
  balance: number;
  birthEpoch: number;
}

export interface EcosystemState {
  totalDeposits: number;
  currentEpoch: number;
  creatureCount: number;
  yieldGenerated: number;
  phase: Phase;
}

export enum Phase {
  IDLE = 0,
  FEEDING = 1,
  HARVESTING = 2,
  EVOLVING = 3,
  ALLOCATING = 4,
}

export interface EpochRecord {
  epoch: number;
  births: number;
  deaths: number;
  topFitness: number;
  avgYield: number;
  populationSize: number;
}

export const POOL_TYPE_NAMES: Record<number, string> = {
  0: "AMM LP",
  1: "Lending",
  2: "Staking",
  3: "Vault",
  4: "Stable Swap",
  5: "Restaking",
};

export const POOL_TYPE_COLORS: Record<number, string> = {
  0: "#6EE7B7", // accent green
  1: "#60A5FA", // blue
  2: "#A855F7", // purple
  3: "#F59E0B", // amber
  4: "#EC4899", // pink
  5: "#EF4444", // red
};

export const CHAIN_NAMES: Record<number, string> = {
  0: "Asset Hub",
  1: "Moonbeam",
  2: "Acala",
  3: "Astar",
  4: "HydraDX",
  5: "Bifrost",
};
