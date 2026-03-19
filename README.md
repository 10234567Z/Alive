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

Compilation target: `riscv32im-unknown-none-elf` (PolkaVM).

This module is the Track 2 submission. EVM contracts call Rust functions through the PVM precompile. The genetic algorithm logic runs natively on RISC-V, not interpreted as EVM bytecode.

### Module 3: AI Seeder (Python)

Directory: `ai-seeder/`

Files:
- `seeder.py` — Main loop. Monitors the Ecosystem for population metrics (diversity index, average fitness, population count). When diversity drops below threshold or population is too small, generates new Creature DNA.
- `dna_generator.py` — Uses an LLM (OpenAI/Claude via LangChain) to generate novel strategy parameter sets. Prompt includes current market conditions and existing population DNA to ensure diversity.
- `market_scanner.py` — Queries parachain RPCs for current yield opportunities, TVL, and pool metadata. Feeds data to the LLM as context.
- `submitter.py` — Signs and submits transactions to the Ecosystem contract to inject new seed Creatures.
- `config.py` — Configuration: RPC URLs, contract addresses, API keys (loaded from `.env`).
- `abi.py` — Contract ABIs for web3 interaction.

The AI Seeder does not control funds. It can only suggest new DNA. The on-chain contracts decide whether to accept the seed based on population rules.

### Module 4: Frontend (Next.js)

Directory: `frontend/`

Key views:
- **Ecosystem View** — The main visualization. A canvas rendering of the living ecosystem. Creatures displayed as nodes. Size proportional to balance. Color encodes strategy type. Lines connect parents to children. Nodes pulse when feeding, fade when dying, split when reproducing.
- **Deposit/Withdraw** — Standard DeFi interface. Connect wallet, approve token, deposit amount.
- **Creature Inspector** — Click any Creature node to see its DNA, performance history, generation, parents, offspring.
- **Epoch Timeline** — Horizontal timeline showing each epoch. What happened: births, deaths, top performer, average yield.
- **Leaderboard** — Ranked list of Creatures by fitness score, returns, and survival streak.

Tech: Next.js 16, TypeScript, wagmi, viem, Recharts, Framer Motion, TailwindCSS v4.

### Module 5: Deployment and Testing

Directory: `scripts/`, `test/`

Testing:
- `test/ALIVE.t.sol` — 23 Foundry tests for deposits, withdrawals, spawning, epoch cycle, factory, creature lifecycle.
- `test/Evolution.t.sol` — 23 tests for fitness scoring, crossover, mutation, XCM flow, full evolution cycle, fitness-weighted allocation.
- `test/XCMRouter.t.sol` — 27 tests for XCM routing, SCALE encoding, message building, asset registration, dual-mode operation.
- `pvm/src/` — 17 Rust unit tests inline for fitness calculation, crossover correctness, mutation bounds.

Deployment:
- `scripts/deploy.sh` — Deploy contracts to Polkadot Hub TestNet.
- `scripts/seed.sh` — Run the AI Seeder to populate initial Creatures.
- `scripts/epoch.sh` — Trigger an epoch manually for demo purposes.
- `keeper/epoch-keeper.sh` — Automated epoch advancement daemon.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Smart Contracts | Solidity 0.8.24, Foundry |
| PVM Module | Rust (`no_std`), compiled to RISC-V for PolkaVM |
| AI Seeder | Python, LangChain, OpenAI API |
| Cross-chain | XCM precompile on Polkadot Hub + SCALE codec |
| Frontend | Next.js 16, TypeScript, wagmi, viem, Recharts, Framer Motion |
| Testing | Foundry (73 tests), Rust (17 tests) |
| Deployment | Polkadot Hub TestNet (Chain 420420417) |

---

## Project Structure

```
polka/
├── contracts/
│   ├── src/
│   │   ├── Ecosystem.sol           # Vault + epoch state machine
│   │   ├── Creature.sol            # Autonomous strategy agent
│   │   ├── GenePool.sol            # Evolution orchestrator
│   │   ├── CreatureFactory.sol     # Deterministic creature deployment
│   │   ├── EvolutionEngine.sol     # EVM fitness/crossover/mutation
│   │   ├── interfaces/
│   │   │   ├── ICreature.sol
│   │   │   ├── IEvolutionEngine.sol
│   │   │   ├── IXCM.sol
│   │   │   └── IPolkadotXcm.sol
│   │   └── xcm/
│   │       ├── ScaleCodec.sol       # SCALE encoding for XCM
│   │       ├── XCMMessageBuilder.sol # XCM V4 message construction
│   │       └── XCMRouter.sol        # Dual-mode XCM adapter
│   ├── test/
│   │   ├── ALIVE.t.sol              # 23 core tests
│   │   ├── Evolution.t.sol          # 23 evolution tests
│   │   ├── XCMRouter.t.sol          # 27 XCM tests
│   │   └── mocks/
│   ├── script/
│   │   ├── Deploy.s.sol             # Local deployment
│   │   ├── DeployProduction.s.sol   # Polkadot Hub TestNet deployment
│   │   └── SpawnCreatures.s.sol     # Spawn initial population
│   └── foundry.toml
├── pvm/
│   ├── src/
│   │   ├── lib.rs                   # PVM precompile entry points
│   │   ├── fitness.rs               # Fitness evaluation
│   │   ├── crossover.rs             # Genome crossover
│   │   ├── mutation.rs              # Genome mutation
│   │   └── types.rs                 # Shared types
│   └── Cargo.toml
├── ai-seeder/
│   ├── seeder.py                    # Main orchestrator
│   ├── dna_generator.py             # LLM-powered DNA generation
│   ├── market_scanner.py            # DeFi market data
│   ├── submitter.py                 # On-chain submission
│   ├── config.py                    # Configuration
│   ├── abi.py                       # Contract ABIs
│   ├── requirements.txt
│   └── .env.example
├── frontend/                        # Next.js 16 Neo-Brutalist dashboard
│   ├── src/
│   │   ├── app/                     # Pages: /, /dashboard, /leaderboard
│   │   ├── components/              # UI components
│   │   ├── hooks/                   # Contract interaction hooks
│   │   ├── stores/                  # Zustand state management
│   │   └── lib/                     # Types, contracts, utilities
│   └── package.json
├── keeper/
│   └── epoch-keeper.sh              # Automated epoch advancement
├── scripts/
│   ├── deploy.sh                    # Testnet deployment
│   ├── seed.sh                      # AI Seeder runner
│   ├── epoch.sh                     # Manual epoch trigger
│   └── epoch-runner.sh              # Epoch simulation
├── docs/
│   └── ARCHITECTURE.md
├── deliverables.md
└── README.md
```

---

## Getting Started

```bash
git clone https://github.com/<your-repo>/polka.git
cd polka

# Contracts
cd contracts
forge install
forge build --via-ir
forge test --via-ir -vv         # 73 tests

# PVM Module
cd ../pvm
cargo test                       # 17 tests (runs on host)
# cargo build --target riscv32im-unknown-none-elf  # for PolkaVM deployment

# AI Seeder
cd ../ai-seeder
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env             # add your RPC endpoints and API keys
python seeder.py

# Frontend
cd ../frontend
npm install
npm run dev                      # http://localhost:3000
```

### Deploy to Polkadot Hub TestNet

```bash
# Deploy contracts to testnet
PRIVATE_KEY=<your-key> forge script script/DeployProduction.s.sol \
  --rpc-url https://eth-rpc-testnet.polkadot.io/ \
  --broadcast --via-ir

# Spawn initial creature population
PRIVATE_KEY=<key> ECOSYSTEM=<addr> forge script script/SpawnCreatures.s.sol \
  --rpc-url https://eth-rpc-testnet.polkadot.io/ \
  --broadcast --via-ir

# Start epoch keeper
bash keeper/epoch-keeper.sh
```

---
