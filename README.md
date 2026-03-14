# ALIVE

Artificial Life DeFi Ecosystem on Polkadot

ALIVE is an evolutionary DeFi protocol where autonomous agents, referred to as Creatures, are spawned with randomized strategy DNA, compete for stablecoin yield across Polkadot parachains, and reproduce or die based on performance. The protocol applies genetic algorithms on-chain to iteratively evolve optimal DeFi strategies without human intervention.

Users deposit stablecoins into the Ecosystem contract. The protocol spawns Creatures, each carrying a unique strategy genome. Creatures forage for yield across connected parachains via XCM. After each epoch, a fitness evaluation runs on PolkaVM (Rust compiled to RISC-V). Top performers reproduce with crossover and mutation. Underperformers are liquidated. Over successive generations, the population converges toward high-performing strategies. Users earn yield proportional to the Creatures their capital backs.

---

## Problem

DeFi yield optimization across multiple chains is manual, fragmented, and static. Users must individually discover opportunities, bridge assets, monitor positions, and rebalance. Automated vaults exist but use fixed strategies that degrade as market conditions shift. There is no mechanism for strategies to adapt autonomously.

## Solution

ALIVE treats DeFi strategies as living organisms. Each strategy has a genome. Strategies that produce yield survive and reproduce. Strategies that fail are killed. The genetic algorithm drives continuous, autonomous adaptation. The system gets smarter every epoch without anyone updating it.

This is only possible on Polkadot because:

- XCM enables native cross-chain fund movement without third-party bridges
- PVM enables complex computation (genetic algorithms in Rust) callable from Solidity
- Shared security across parachains means Creatures can operate across chains under a single trust model

---

## System Architecture

```
USER
  |
  | Deposits stablecoins
  v
ECOSYSTEM CONTRACT (Solidity, Polkadot Hub EVM)
  |
  |-- Spawns Creatures with random DNA
  |-- Manages capital allocation per Creature
  |-- Triggers epoch transitions
  |
  v
CREATURE CONTRACT (Solidity, Polkadot Hub EVM)
  |
  |-- Stores DNA (strategy parameters)
  |-- Holds allocated capital
  |-- Executes yield strategies via XCM
  |-- Reports returns at end of epoch
  |
  |----> XCM PRECOMPILE ----> TARGET PARACHAIN
  |                           (Hydration, Acala, Moonbeam, etc.)
  |                           Deposits into yield pools
  |                           Harvests returns
  |                           Transfers back via XCM
  |
  v
GENE POOL CONTRACT (Solidity, Polkadot Hub EVM)
  |
  |-- Receives fitness scores from Evolution Engine
  |-- Selects parents (top performers)
  |-- Creates offspring with crossover + mutation
  |-- Kills underperformers, recycles their capital
  |
  |----> PVM PRECOMPILE ----> EVOLUTION ENGINE (Rust, PolkaVM)
                              |
                              |-- Calculates fitness: risk-adjusted return,
                              |   Sharpe ratio, max drawdown, consistency
                              |-- Runs crossover: combines parent genomes
                              |-- Applies mutation: random parameter shifts
                              |-- Returns ranked results to GenePool

AI SEEDER (Python, Off-chain)
  |
  |-- Generates initial Creature DNA using LLM
  |-- Provides strategy templates and parameter ranges
  |-- Monitors ecosystem health metrics
  |-- Submits new seed Creatures to maintain diversity
```

---

## Core Concepts

### Creature DNA

Every Creature has a genome stored on-chain as a struct. The genome encodes the Creature's entire strategy behavior:

```
DNA {
    targetChainId       // Which parachain to forage on
    poolType            // AMM LP, lending, staking, etc.
    allocationRatio     // What percentage of capital to deploy
    rebalanceThreshold  // At what drift percentage to rebalance
    maxSlippage         // Slippage tolerance
    yieldFloor          // Minimum APY to consider
    riskCeiling         // Maximum acceptable risk score
    entryTiming         // Epoch offset for entry (avoids herding)
    exitTiming          // How many epochs to hold before harvesting
    hedgeRatio          // Portion of capital kept as reserve
}
```

Each field is an integer in a bounded range. Crossover swaps fields between two parents. Mutation randomly shifts a field within its range.

### Epoch Cycle

The protocol operates in fixed-length epochs. Each epoch follows this sequence:

```
1. FEED PHASE
   Creatures execute their strategies: move capital via XCM,
   deposit into yield sources, harvest returns.

2. SCORE PHASE
   Evolution Engine (PVM) calculates fitness for every Creature
   based on returns, risk, drawdown, and consistency.

3. SELECT PHASE
   Top 30% of Creatures are selected as parents.
   Bottom 20% are killed. Their capital is redistributed.

4. BREED PHASE
   Parents reproduce via crossover and mutation.
   New Creatures are spawned with offspring DNA.
   Capital is allocated to offspring from the recycled pool.

5. INJECT PHASE (periodic)
   AI Seeder introduces fresh Creatures with novel DNA
   to prevent population stagnation and local optima.
```

### Fitness Function

Computed in Rust on PolkaVM. This is not a simple return comparison. The fitness function rewards consistency over volatility:

```
fitness = (annualized_return * 0.4)
        + (sharpe_ratio * 0.3)
        - (max_drawdown * 0.2)
        + (epoch_survival_count * 0.1)
```

Creatures that produce moderate but stable returns over many epochs score higher than Creatures that spike once and crash.

---

## Module Breakdown

The project is divided into five independent modules. Each can be developed and tested in isolation.

### Module 1: Core Contracts (Solidity)

Directory: `contracts/src/`

Files:
- `Ecosystem.sol` — Top-level vault. Handles user deposits and withdrawals. Manages global epoch counter. Allocates capital to Creatures. Distributes yield back to depositors.
- `Creature.sol` — Represents a single Creature. Stores DNA, current balance, age (epochs survived), generation number, parent IDs. Exposes functions to execute strategy (calls XCM precompile) and report returns.
- `GenePool.sol` — Manages reproduction. Receives fitness rankings from the Evolution Engine. Selects parents, creates offspring DNA via crossover and mutation, kills underperformers, spawns new Creature contracts.
- `CreatureFactory.sol` — Factory pattern for deploying new Creature contracts. Uses CREATE2 for deterministic addressing.
- `interfaces/IEvolutionEngine.sol` — Interface for calling the PVM Evolution Engine from Solidity.
- `interfaces/IXCM.sol` — High-level XCM adapter interface that Creatures call to deploy capital cross-chain.
- `interfaces/IPolkadotXcm.sol` — Real Polkadot Hub XCM precompile interface at `0x0...0A0000` (execute, send, weighMessage with SCALE-encoded messages).
- `xcm/ScaleCodec.sol` — SCALE encoding library for building XCM messages in Solidity (compact integers, LE encoding, Location/Junction/Asset encoding).
- `xcm/XCMMessageBuilder.sol` — Builds SCALE-encoded XCM V4 programs (TransferReserveAsset, WithdrawAsset+DepositReserveAsset with inner BuyExecution+DepositAsset).
- `xcm/XCMRouter.sol` — Dual-mode XCM adapter (PRODUCTION: real precompile calls, SIMULATION: local token transfers for testing). Maps ERC20 tokens to pallet-assets GeneralIndex (USDT=1984, USDC=1337).

Dependencies: OpenZeppelin (ERC20, SafeERC20), XCM precompile interface.

### Module 2: Evolution Engine (Rust / PVM)

Directory: `pvm/`

Files:
- `src/lib.rs` — Entry point. Exposes functions callable from EVM via PVM precompile.
- `src/fitness.rs` — Fitness scoring. Takes an array of Creature performance records, computes fitness scores, returns ranked list.
- `src/crossover.rs` — Genome crossover. Takes two parent DNA structs, produces offspring DNA using single-point or uniform crossover.
- `src/mutation.rs` — Genome mutation. Randomly perturbs one or more fields within bounded ranges.
- `src/types.rs` — Shared types: DNA struct, PerformanceRecord, FitnessScore.

Compilation target: `riscv32em-unknown-none-elf` (PolkaVM).

This module is the Track 2 submission. EVM contracts call Rust functions through the PVM precompile. The genetic algorithm logic runs natively on RISC-V, not interpreted as EVM bytecode.

### Module 3: AI Seeder (Python)

Directory: `agents/`

Files:
- `seeder.py` — Main loop. Monitors the Ecosystem for population metrics (diversity index, average fitness, population count). When diversity drops below threshold or population is too small, generates new Creature DNA.
- `dna_generator.py` — Uses an LLM (OpenAI/Claude) to generate novel strategy parameter sets. Prompt includes current market conditions and existing population DNA to ensure diversity.
- `market_scanner.py` — Queries parachain RPCs and indexers (Subsquid) for current yield opportunities, TVL, and pool metadata. Feeds data to the LLM as context.
- `submitter.py` — Signs and submits transactions to the Ecosystem contract to inject new seed Creatures.
- `config.yaml` — RPC endpoints, LLM API keys, population thresholds, submission intervals.

The AI Seeder does not control funds. It can only suggest new DNA. The on-chain contracts decide whether to accept the seed based on population rules.

### Module 4: Frontend (Next.js)

Directory: `frontend/`

Key views:
- **Ecosystem View** — The main visualization. A canvas rendering of the living ecosystem. Creatures displayed as nodes. Size proportional to balance. Color encodes strategy type. Lines connect parents to children. Nodes pulse when feeding, fade when dying, split when reproducing.
- **Deposit/Withdraw** — Standard DeFi interface. Connect wallet, approve token, deposit amount.
- **Creature Inspector** — Click any Creature node to see its DNA, performance history, generation, parents, offspring.
- **Epoch Timeline** — Horizontal timeline showing each epoch. What happened: births, deaths, top performer, average yield.
- **Leaderboard** — Ranked list of Creatures by fitness score, returns, and survival streak.

Tech: Next.js, TypeScript, wagmi, viem, ethers.js, HTML Canvas (for ecosystem visualization).

### Module 5: Deployment and Testing

Directory: `scripts/`, `test/`

Testing:
- `test/Ecosystem.t.sol` — Foundry tests for deposit, withdraw, epoch transitions, capital allocation.
- `test/Creature.t.sol` — Tests for DNA storage, strategy execution mocking, return reporting.
- `test/GenePool.t.sol` — Tests for crossover logic, mutation bounds, kill conditions, reproduction.
- `test/integration/` — Full lifecycle test: deposit, spawn, feed, score, breed, withdraw.
- `pvm/tests/` — Rust unit tests for fitness calculation, crossover correctness, mutation bounds.
- `agents/tests/` — Python tests for DNA generation, market scanning, transaction submission.

Deployment:
- `scripts/deploy.sh` — Deploy contracts to Polkadot Hub testnet (Westend).
- `scripts/seed.sh` — Run the AI Seeder to populate initial Creatures.
- `scripts/epoch.sh` — Trigger an epoch manually for demo purposes.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Smart Contracts | Solidity, Foundry |
| PVM Module | Rust, compiled to RISC-V for PolkaVM |
| AI Seeder | Python, LangChain, OpenAI API |
| Cross-chain | XCM precompile on Polkadot Hub |
| Indexing | Subsquid |
| Frontend | Next.js, TypeScript, wagmi, viem, Canvas API |
| Testing | Foundry (forge), pytest, Rust unit tests |
| Deployment | Polkadot Hub Testnet (Westend) |

---

## Project Structure

```
polka/
├── contracts/
│   ├── src/
│   │   ├── Ecosystem.sol
│   │   ├── Creature.sol
│   │   ├── GenePool.sol
│   │   ├── CreatureFactory.sol
│   │   ├── interfaces/
│   │   │   ├── IEvolutionEngine.sol
│   │   │   ├── ICreature.sol
│   │   │   ├── IXCM.sol
│   │   │   └── IPolkadotXcm.sol
│   │   └── xcm/
│   │       ├── ScaleCodec.sol
│   │       ├── XCMMessageBuilder.sol
│   │       └── XCMRouter.sol
│   ├── test/
│   │   ├── ALIVE.t.sol
│   │   ├── Evolution.t.sol
│   │   ├── XCMRouter.t.sol
│   │   └── mocks/
│   │       ├── MockXCM.sol
│   │       ├── MockStablecoin.sol
│   │       └── MockEvolutionEngine.sol
│   ├── script/
│   │   ├── Deploy.s.sol
│   │   └── DeployProduction.s.sol
│   └── foundry.toml
├── pvm/
│   ├── src/
│   │   ├── lib.rs
│   │   ├── fitness.rs
│   │   ├── crossover.rs
│   │   ├── mutation.rs
│   │   └── types.rs
│   ├── tests/
│   └── Cargo.toml
├── agents/
│   ├── seeder.py
│   ├── dna_generator.py
│   ├── market_scanner.py
│   ├── submitter.py
│   ├── config.yaml
│   ├── requirements.txt
│   └── tests/
├── frontend/
│   ├── src/
│   │   ├── app/
│   │   ├── components/
│   │   │   ├── EcosystemCanvas.tsx
│   │   │   ├── CreatureInspector.tsx
│   │   │   ├── DepositPanel.tsx
│   │   │   ├── EpochTimeline.tsx
│   │   │   └── Leaderboard.tsx
│   │   ├── hooks/
│   │   └── lib/
│   └── package.json
├── scripts/
│   ├── deploy.sh
│   ├── seed.sh
│   └── epoch.sh
├── docs/
│   └── ARCHITECTURE.md
└── README.md
```

---

## Getting Started

```bash
git clone https://github.com/<your-repo>/alive.git
cd alive

# Contracts
cd contracts
forge install
forge build
forge test

# PVM Module
cd ../pvm
cargo build --target riscv32em-unknown-none-elf

# AI Seeder
cd ../agents
pip install -r requirements.txt
cp config.yaml.example config.yaml  # add your RPC endpoints and API keys
python seeder.py

# Frontend
cd ../frontend
npm install
npm run dev
```

---
