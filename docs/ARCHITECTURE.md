# ALIVE Architecture Document

This document describes the internal architecture of ALIVE in detail. It covers every contract, module, data structure, and interaction flow with enough precision to implement the system from scratch.

---

## 1. On-Chain Layer (Polkadot Hub EVM)

All Solidity contracts are deployed on Polkadot Hub. They manage capital, creature lifecycle, and cross-chain execution.

### 1.1 Ecosystem.sol

The top-level entry point. All user capital flows through this contract.

State:
```
mapping(address => uint256) public deposits;
uint256 public totalDeposits;
uint256 public currentEpoch;
uint256 public epochDuration;              // in blocks
uint256 public lastEpochBlock;
address[] public activeCreatures;
address public genePoolAddress;
address public creatureFactoryAddress;
IERC20 public stablecoin;                  // USDC on Polkadot Hub
```

Functions:
- `deposit(uint256 amount)` — User deposits stablecoins. Updates their share of the ecosystem. Emits `Deposited(user, amount)`.
- `withdraw(uint256 amount)` — User withdraws their proportional share of ecosystem capital plus accumulated yield. Emits `Withdrawn(user, amount)`.
- `advanceEpoch()` — Can be called by anyone once `epochDuration` blocks have passed since `lastEpochBlock`. Triggers the full epoch cycle: score, select, breed, allocate. Calls `GenePool.runEvolution()`.
- `spawnInitialCreatures(bytes[] calldata dnaList)` — Called once after deployment or by the AI Seeder. Deploys initial Creatures via CreatureFactory.
- `allocateCapital()` — Internal. Distributes total ecosystem capital across active Creatures weighted by their fitness scores.
- `getEcosystemState()` — View function. Returns total deposits, epoch number, active creature count, total yield generated.

### 1.2 Creature.sol

Each Creature is a separate contract instance. It holds its own capital and executes its strategy autonomously.

State:
```
struct DNA {
    uint8 targetChainId;
    uint8 poolType;
    uint16 allocationRatio;       // basis points, 0-10000
    uint16 rebalanceThreshold;    // basis points
    uint16 maxSlippage;           // basis points
    uint16 yieldFloor;            // basis points annualized
    uint8 riskCeiling;            // 1-10
    uint8 entryTiming;            // epoch offset 0-5
    uint8 exitTiming;             // epochs to hold 1-10
    uint16 hedgeRatio;            // basis points
}

DNA public dna;
uint256 public balance;
uint256 public initialBalance;
uint256 public birthEpoch;
uint256 public generation;
address public parent1;
address public parent2;
uint256 public lastReturn;                // return from most recent epoch
uint256 public cumulativeReturn;
uint256 public epochsSurvived;
bool public alive;
address public ecosystemAddress;
```

Functions:
- `initialize(DNA memory _dna, uint256 _generation, address _parent1, address _parent2, uint256 _birthEpoch)` — Called by CreatureFactory at deployment. Sets genome and metadata.
- `feed()` — Executes the Creature's strategy for the current epoch. Reads DNA parameters to determine target chain, pool, and allocation. Calls the XCM precompile to transfer capital to the target parachain and deposit into the yield source. This is the core execution function.
- `harvest()` — Called at end of epoch. Retrieves returns from the target parachain via XCM. Updates `lastReturn` and `cumulativeReturn`. Sends returns back to Ecosystem.
- `kill()` — Called by GenePool when the Creature is selected for death. Transfers remaining balance back to Ecosystem. Sets `alive = false`.
- `receiveCapital(uint256 amount)` — Called by Ecosystem during capital allocation. Accepts stablecoins.
- `getDNA()` — View. Returns the full DNA struct.
- `getPerformance()` — View. Returns lastReturn, cumulativeReturn, epochsSurvived, balance.

### 1.3 GenePool.sol

Manages the evolutionary cycle. Orchestrates scoring, selection, reproduction, and death.

State:
```
address public ecosystemAddress;
address public creatureFactoryAddress;
address public evolutionEngineAddress;     // PVM precompile address
uint256 public survivalThreshold;          // top N% survive
uint256 public deathThreshold;             // bottom N% die
uint256 public mutationRate;               // basis points probability
uint256 public maxPopulation;
```

Functions:
- `runEvolution(address[] calldata creatures)` — Called by Ecosystem at epoch transition. This is the main evolutionary loop:
  1. Collects performance data from all Creatures.
  2. Calls Evolution Engine (PVM) via precompile with the performance array.
  3. Receives ranked fitness scores.
  4. Selects top performers as parents (above `survivalThreshold`).
  5. Kills bottom performers (below `deathThreshold`).
  6. For each pair of parents, creates offspring via `breed()`.
  7. Returns the new active Creatures list to Ecosystem.
- `breed(address parent1, address parent2, uint256 generation)` — Calls Evolution Engine (PVM) to perform crossover on the two parent DNAs. Applies mutation with probability `mutationRate`. Deploys new Creature via CreatureFactory with the offspring DNA.
- `injectSeed(bytes calldata dna)` — Called by the AI Seeder (authorized address) to introduce a new Creature with externally generated DNA. Subject to `maxPopulation` cap.

### 1.4 CreatureFactory.sol

Factory for deploying Creature contract instances.

Functions:
- `deploy(DNA memory dna, uint256 generation, address parent1, address parent2, uint256 epoch)` — Deploys a new Creature using CREATE2. Calls `initialize()` on the new instance. Returns the deployed address.
- `computeAddress(DNA memory dna, uint256 nonce)` — View. Computes the deterministic address for a given DNA and nonce.

### 1.5 IEvolutionEngine.sol (Interface)

Defines the interface for calling the PVM Evolution Engine from Solidity.

```
interface IEvolutionEngine {
    struct PerformanceRecord {
        uint256 creatureId;
        int256 lastReturn;
        int256 cumulativeReturn;
        uint256 epochsSurvived;
        int256 maxDrawdown;
    }

    struct FitnessResult {
        uint256 creatureId;
        uint256 fitnessScore;
    }

    function evaluateFitness(PerformanceRecord[] calldata records)
        external view returns (FitnessResult[] memory);

    function crossover(bytes calldata parent1Dna, bytes calldata parent2Dna)
        external view returns (bytes memory offspringDna);

    function mutate(bytes calldata dna, uint256 mutationRate)
        external view returns (bytes memory mutatedDna);
}
```

This interface is called via the PVM precompile address. The implementation runs as compiled Rust on PolkaVM.

---

## 2. PVM Layer (Rust / PolkaVM)

The Evolution Engine runs computationally intensive genetic algorithm operations natively on RISC-V. EVM contracts call it through the PVM precompile.

### 2.1 types.rs

Shared data structures matching the Solidity interface ABI-encoded inputs.

```rust
pub struct DNA {
    pub target_chain_id: u8,
    pub pool_type: u8,
    pub allocation_ratio: u16,
    pub rebalance_threshold: u16,
    pub max_slippage: u16,
    pub yield_floor: u16,
    pub risk_ceiling: u8,
    pub entry_timing: u8,
    pub exit_timing: u8,
    pub hedge_ratio: u16,
}

pub struct PerformanceRecord {
    pub creature_id: u64,
    pub last_return: i64,
    pub cumulative_return: i64,
    pub epochs_survived: u64,
    pub max_drawdown: i64,
}

pub struct FitnessResult {
    pub creature_id: u64,
    pub fitness_score: u64,
}
```

### 2.2 fitness.rs

Computes fitness for a batch of Creatures.

```
fitness(record) =
    (annualized_return * 40)
  + (sharpe_ratio * 30)
  - (max_drawdown_penalty * 20)
  + (survival_bonus * 10)
```

Where:
- `annualized_return` = `cumulative_return / epochs_survived`, scaled
- `sharpe_ratio` = `mean_return / return_stddev` (computed over epoch history)
- `max_drawdown_penalty` = absolute value of worst single-epoch loss
- `survival_bonus` = `min(epochs_survived, 20)` (capped to prevent immortality bias)

Input: array of PerformanceRecord.
Output: array of FitnessResult, sorted descending by fitness_score.

### 2.3 crossover.rs

Takes two parent DNA structs. Produces one offspring.

Method: Uniform crossover. For each field in the DNA struct, randomly select from parent1 or parent2 with equal probability. The randomness source is a seed derived from the block hash passed in from the EVM caller.

```rust
pub fn crossover(parent1: &DNA, parent2: &DNA, seed: u64) -> DNA {
    // For each field, use bit N of seed to pick parent
    DNA {
        target_chain_id: if seed & 1 != 0 { parent1.target_chain_id } else { parent2.target_chain_id },
        pool_type: if seed & 2 != 0 { parent1.pool_type } else { parent2.pool_type },
        // ... same pattern for all fields
    }
}
```

### 2.4 mutation.rs

Takes a DNA struct and a mutation rate (basis points). For each field, with probability `mutation_rate / 10000`, replaces the value with a random value within the field's valid range.

Valid ranges:
- `target_chain_id`: 0-255 (parachain ID space)
- `pool_type`: 0-5 (enum: AMM_LP, LENDING, STAKING, VAULT, STABLE_SWAP, RESTAKING)
- `allocation_ratio`: 1000-10000 (10%-100%)
- `rebalance_threshold`: 100-2000 (1%-20%)
- `max_slippage`: 10-500 (0.1%-5%)
- `yield_floor`: 100-5000 (1%-50% annualized)
- `risk_ceiling`: 1-10
- `entry_timing`: 0-5
- `exit_timing`: 1-10
- `hedge_ratio`: 0-5000 (0%-50%)

### 2.5 lib.rs

Entry point exposing three functions matching the IEvolutionEngine interface:
- `evaluate_fitness(records: Vec<PerformanceRecord>) -> Vec<FitnessResult>`
- `crossover(parent1: DNA, parent2: DNA, seed: u64) -> DNA`
- `mutate(dna: DNA, mutation_rate: u16, seed: u64) -> DNA`

ABI encoding/decoding handles conversion between EVM calldata and Rust structs.

---

## 3. Off-Chain Layer (Python AI Seeder)

The AI Seeder is the only off-chain component. It does not control funds. It can only submit new Creature DNA to the on-chain ecosystem through a permissioned function.

### 3.1 market_scanner.py

Queries yield data across Polkadot parachains.

Data sources:
- Subsquid indexers for historical pool performance
- Parachain RPCs for current TVL, APY, pool composition

Output: A JSON object per yield source:
```json
{
    "chain_id": 2034,
    "chain_name": "Hydration",
    "pool_address": "0x...",
    "pool_type": "STABLE_SWAP",
    "current_apy": 1240,
    "tvl_usd": 5200000,
    "age_days": 180,
    "token_pair": ["USDC", "USDT"]
}
```

### 3.2 dna_generator.py

Takes market scanner output and the current ecosystem population DNA as input. Sends both to an LLM with the prompt:

```
Given the current yield opportunities across Polkadot parachains and the
existing population of DeFi strategy creatures, generate 5 new diverse
creature DNA configurations that explore underrepresented strategy spaces.
Each DNA must conform to the following schema and ranges: [schema]
Current population DNA: [population]
Available yield sources: [market_data]
```

Parses the LLM response into valid DNA structs. Validates all fields are within bounds.

### 3.3 seeder.py

Main loop:
1. Every N blocks, query the Ecosystem contract for population metrics: count, average fitness, diversity index (number of unique targetChainId values / population).
2. If diversity index < 0.3 or population < minimum threshold, trigger DNA generation.
3. Call `dna_generator.py` to produce new DNA.
4. Submit each DNA to `GenePool.injectSeed()` via signed transaction.

### 3.4 submitter.py

Handles wallet management and transaction signing. Reads private key from environment. Constructs and sends transactions to the GenePool contract. Handles nonce management and gas estimation.

---

## 4. Cross-Chain Flow (XCM)

When a Creature executes its strategy, the cross-chain flow is:

```
1. Creature.feed() is called on Polkadot Hub
2. Creature reads its DNA: targetChainId = 2034 (Hydration), poolType = STABLE_SWAP
3. Creature calls the XCM precompile on Polkadot Hub:
   - Constructs an XCM message: TransferAsset(USDC, amount) + Transact(deposit_into_pool)
   - Destination: parachain 2034
   - Assets: USDC amount from Creature's balance
4. XCM message is routed through Polkadot relay chain to Hydration
5. On Hydration: USDC is received, deposited into the specified pool
6. At harvest time: Creature.harvest() sends a reverse XCM message
   - Withdraws USDC + yield from the Hydration pool
   - Transfers back to the Creature's address on Polkadot Hub
7. Creature updates its return metrics
```

The XCM precompile address on Polkadot Hub provides the following interface from Solidity:

```solidity
interface IXCM {
    function transferAssets(
        uint256 destChainId,
        address destAccount,
        address asset,
        uint256 amount,
        bytes calldata transactPayload
    ) external returns (bool);
}
```

---

## 5. Epoch State Machine

```
IDLE
  |
  | advanceEpoch() called (enough blocks passed)
  v
FEEDING
  |
  | All Creatures execute feed() — deploy capital via XCM
  | Duration: partial epoch (first half)
  v
HARVESTING
  |
  | All Creatures execute harvest() — collect returns via XCM
  | Duration: partial epoch (second half)
  v
EVOLVING
  |
  | GenePool.runEvolution() called
  | PVM fitness scoring, selection, breeding, killing
  v
ALLOCATING
  |
  | Ecosystem.allocateCapital() distributes capital to new population
  v
IDLE (next epoch)
```

For the hackathon MVP, epoch transitions are triggered manually via `advanceEpoch()`. In production, this would be automated via a keeper or cron job.

---

## 6. Frontend Architecture

### 6.1 Ecosystem Canvas (EcosystemCanvas.tsx)

HTML Canvas rendering at 60fps. The visualization logic:

- Each Creature is a circle on the canvas
- Circle radius = `sqrt(creature.balance / totalBalance) * maxRadius`
- Circle color = hue mapped from `creature.dna.poolType` (each strategy type has a distinct color)
- Circle opacity = `creature.alive ? 1.0 : 0.0` (fades on death)
- Position: force-directed layout. Creatures with similar DNA cluster together. Dissimilar ones repel.
- Lines connect parent to child (rendered with low opacity)
- Animation events:
  - Birth: circle grows from zero radius with a pulse
  - Death: circle shrinks to zero and fades
  - Feeding: circle moves toward the edge representing the target parachain
  - Reproducing: two parent circles emit a new small circle between them

The canvas reads state from on-chain data fetched via wagmi hooks. Poll interval: every new block.

### 6.2 Other Components

- `DepositPanel.tsx` — Standard deposit/withdraw form. Calls Ecosystem.deposit() and Ecosystem.withdraw().
- `CreatureInspector.tsx` — Modal that opens on clicking a Creature circle. Shows DNA fields, performance history chart, generation tree.
- `EpochTimeline.tsx` — Horizontal scrollable bar. Each epoch shows: births, deaths, top fitness, average yield. Click an epoch to replay the state.
- `Leaderboard.tsx` — Table sorted by fitness score. Columns: rank, address, generation, epochs survived, cumulative return, fitness.

---

## 7. Data Flow Summary

```
User deposits USDC
        |
        v
Ecosystem holds capital
        |
        v
Capital allocated to Creatures (weighted by fitness)
        |
        v
Creatures feed: move capital to parachains via XCM
        |
        v
Yield accumulates on target parachains
        |
        v
Creatures harvest: pull returns back via XCM
        |
        v
GenePool calls Evolution Engine (PVM)
        |
        v
PVM scores fitness, ranks Creatures
        |
        v
Top Creatures breed (crossover + mutation in PVM)
        |
        v
Bottom Creatures killed, capital recycled
        |
        v
New generation spawned with offspring DNA
        |
        v
Capital reallocated to new population
        |
        v
User's deposit has grown by the ecosystem's net yield
```

---

## 8. Module Dependency Graph

```
Ecosystem.sol
    ├── depends on: Creature.sol (calls feed, harvest, kill, getPerformance)
    ├── depends on: GenePool.sol (calls runEvolution)
    ├── depends on: CreatureFactory.sol (calls deploy)
    └── depends on: IERC20 (stablecoin)

GenePool.sol
    ├── depends on: IEvolutionEngine (PVM precompile calls)
    ├── depends on: CreatureFactory.sol (deploys offspring)
    └── depends on: Creature.sol (reads DNA, performance)

CreatureFactory.sol
    └── depends on: Creature.sol (deploys instances)

Creature.sol
    ├── depends on: IXCM (XCM precompile for cross-chain)
    └── depends on: IERC20 (stablecoin transfers)

Evolution Engine (PVM)
    └── standalone, called via precompile from GenePool.sol

AI Seeder (Python)
    └── calls: GenePool.injectSeed() via RPC

Frontend (Next.js)
    └── reads: Ecosystem, Creature, GenePool state via RPC
    └── writes: Ecosystem.deposit(), Ecosystem.withdraw(), Ecosystem.advanceEpoch()
```