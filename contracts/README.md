# ALIVE Protocol — Solidity Smart Contracts

Solidity 0.8.24 contracts for the ALIVE evolutionary DeFi protocol on Polkadot.

## Structure

- `src/Ecosystem.sol` — Vault + epoch state machine
- `src/Creature.sol` — Autonomous strategy agent
- `src/GenePool.sol` — Evolution orchestrator
- `src/CreatureFactory.sol` — Deterministic creature deployment
- `src/EvolutionEngine.sol` — Fitness scoring, crossover, mutation
- `src/xcm/` — XCM routing, SCALE codec, message builder
- `test/` — 73 Foundry tests (ALIVE, Evolution, XCMRouter)
- `script/` — Deploy + spawn scripts

## Build & Test

```bash
forge build --via-ir
forge test --via-ir -vvv
```

## Deploy

```bash
# Local
anvil --chain-id 420420417
forge script script/Deploy.s.sol --via-ir --broadcast --rpc-url http://localhost:8545

# Polkadot Hub TestNet
forge script script/DeployProduction.s.sol \
  --rpc-url https://eth-rpc-testnet.polkadot.io/ \
  --broadcast --via-ir
```

