// ── ALIVE Protocol — Contract ABIs (minimal, view functions only) ──

export const EcosystemABI = [
  {
    type: "function",
    name: "getEcosystemState",
    inputs: [],
    outputs: [
      { name: "deposits", type: "uint256" },
      { name: "epoch", type: "uint256" },
      { name: "creatureCount", type: "uint256" },
      { name: "yieldGenerated", type: "int256" },
      { name: "currentPhase", type: "uint8" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getActiveCreatures",
    inputs: [],
    outputs: [{ name: "", type: "address[]" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "shares",
    inputs: [{ name: "", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "shareValue",
    inputs: [{ name: "user", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "totalShares",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "totalCapital",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "currentEpoch",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "phase",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "deposit",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "withdraw",
    inputs: [{ name: "sharesToBurn", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "latestFitness",
    inputs: [{ name: "", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "advanceEpoch",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "epochDuration",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "lastEpochBlock",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "totalSystemValue",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "event",
    name: "EpochAdvanced",
    inputs: [
      { name: "epoch", type: "uint256", indexed: true },
      { name: "phase", type: "uint8", indexed: false },
    ],
  },
] as const;

export const CreatureABI = [
  {
    type: "function",
    name: "getDNA",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "targetChainId", type: "uint8" },
          { name: "poolType", type: "uint8" },
          { name: "allocationRatio", type: "uint16" },
          { name: "rebalanceThreshold", type: "uint16" },
          { name: "maxSlippage", type: "uint16" },
          { name: "yieldFloor", type: "uint16" },
          { name: "riskCeiling", type: "uint8" },
          { name: "entryTiming", type: "uint8" },
          { name: "exitTiming", type: "uint8" },
          { name: "hedgeRatio", type: "uint16" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getPerformance",
    inputs: [],
    outputs: [
      { name: "", type: "int256" },
      { name: "", type: "int256" },
      { name: "", type: "uint256" },
      { name: "", type: "int256" },
      { name: "", type: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "generation",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "parent1",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "parent2",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isAlive",
    inputs: [],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "balance",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "birthEpoch",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
] as const;

export const GenePoolABI = [
  {
    type: "event",
    name: "EvolutionRun",
    inputs: [
      { name: "epoch", type: "uint256", indexed: false },
      { name: "totalCreatures", type: "uint256", indexed: false },
      { name: "killed", type: "uint256", indexed: false },
      { name: "bred", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "CreatureKilled",
    inputs: [
      { name: "creature", type: "address", indexed: true },
      { name: "fitnessScore", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "CreatureBred",
    inputs: [
      { name: "offspring", type: "address", indexed: true },
      { name: "parent1", type: "address", indexed: true },
      { name: "parent2", type: "address", indexed: true },
      { name: "generation", type: "uint256", indexed: false },
    ],
  },
  {
    type: "function",
    name: "getFitness",
    inputs: [{ name: "creature", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
] as const;

export const ERC20ABI = [
  {
    type: "function",
    name: "approve",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "allowance",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
] as const;
