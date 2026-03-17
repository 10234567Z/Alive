// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Ecosystem} from "../src/Ecosystem.sol";
import {Creature} from "../src/Creature.sol";
import {CreatureFactory} from "../src/CreatureFactory.sol";
import {GenePool} from "../src/GenePool.sol";
import {EvolutionEngine} from "../src/EvolutionEngine.sol";
import {MockStablecoin} from "../test/mocks/MockStablecoin.sol";
import {XCMRouter} from "../src/xcm/XCMRouter.sol";

/// @title Deploy
/// @notice Foundry deployment script for the ALIVE Protocol (local / testnet).
///
///         Uses XCMRouter in SIMULATION mode for local testing (Anvil).
///         The XCMRouter is the same contract used in production — it just
///         switches to local token transfers instead of calling the real
///         XCM precompile. This ensures the code path is identical.
///
///         For production deployment on Westend Asset Hub, use DeployProduction.s.sol.
///
///         Deploy Order:
///         1. MockStablecoin (testnet USDC)
///         2. XCMRouter (SIMULATION mode — same interface as production)
///         3. EvolutionEngine (production PVM engine — real fitness/crossover/mutation)
///         4. CreatureFactory(stablecoin, xcmRouter)
///         5. Ecosystem(stablecoin, factory, epochDuration)
///         6. GenePool(ecosystem, factory, evolutionEngine, ...)
///         7. Wire: factory.setEcosystem(), factory.setGenePool(), ecosystem.setGenePool()
///         8. Mint yield supply to XCMRouter for return simulation
contract Deploy is Script {
    // ----- Config -----
    uint256 constant EPOCH_DURATION = 100; // blocks per epoch
    uint256 constant SURVIVAL_THRESHOLD = 3000; // top 30% survive
    uint256 constant DEATH_THRESHOLD = 2000; // bottom 20% die
    uint256 constant MUTATION_RATE = 1000; // 10%
    uint256 constant MAX_POPULATION = 100; // max creatures
    uint256 constant INITIAL_MINT = 1_000_000e6; // 1M USDC (6 decimals)
    uint256 constant XCM_YIELD_SUPPLY = 500_000e6; // 500K USDC for yield simulation
    uint32 constant ASSET_HUB_PARA_ID = 1000; // Asset Hub parachain ID

    function run() external {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);

        console2.log("=== ALIVE Protocol Deployment ===");
        console2.log("Deployer:", deployer);
        console2.log("");

        vm.startBroadcast(deployerPK);

        // ---- Step 1: Deploy MockStablecoin ----
        MockStablecoin stablecoin = new MockStablecoin();
        console2.log("1. MockStablecoin:", address(stablecoin));

        // Mint initial supply to deployer
        stablecoin.mint(deployer, INITIAL_MINT);
        console2.log("   Minted", INITIAL_MINT / 1e6, "USDC to deployer");

        // ---- Step 2: Deploy XCMRouter (SIMULATION mode) ----
        // Same contract as production — just in simulation mode for local testing.
        // In production, this switches to Mode.PRODUCTION and calls the real
        // Polkadot Hub XCM precompile at 0x0...0A0000.
        XCMRouter xcmRouter = new XCMRouter(
            XCMRouter.Mode.SIMULATION,
            ASSET_HUB_PARA_ID
        );
        console2.log("2. XCMRouter (SIMULATION):", address(xcmRouter));

        // Mint yield supply to XCMRouter so it can pay out simulated returns
        stablecoin.mint(address(xcmRouter), XCM_YIELD_SUPPLY);
        console2.log("   Minted", XCM_YIELD_SUPPLY / 1e6, "USDC to XCMRouter for yields");

        // ---- Step 3: Deploy EvolutionEngine (REAL, not mock) ----
        EvolutionEngine evolutionEngine = new EvolutionEngine();
        console2.log("3. EvolutionEngine:", address(evolutionEngine));
        console2.log("   (Real fitness/crossover/mutation - ports PVM Rust logic)");

        // ---- Step 4: Deploy CreatureFactory ----
        CreatureFactory factory = new CreatureFactory(
            address(stablecoin),
            address(xcmRouter)
        );
        console2.log("4. CreatureFactory:", address(factory));

        // ---- Step 5: Deploy Ecosystem ----
        Ecosystem ecosystem = new Ecosystem(
            address(stablecoin),
            address(factory),
            EPOCH_DURATION
        );
        console2.log("5. Ecosystem:", address(ecosystem));

        // ---- Step 6: Deploy GenePool ----
        GenePool genePool = new GenePool(
            address(ecosystem),
            address(factory),
            address(evolutionEngine),
            SURVIVAL_THRESHOLD,
            DEATH_THRESHOLD,
            MUTATION_RATE,
            MAX_POPULATION,
            deployer // seeder = deployer for now (AI Seeder address)
        );
        console2.log("6. GenePool:", address(genePool));

        // ---- Step 7: Wire circular dependencies ----
        factory.setEcosystem(address(ecosystem));
        factory.setGenePool(address(genePool));
        ecosystem.setGenePool(address(genePool));
        ecosystem.setXCMRouter(address(xcmRouter));
        console2.log("7. Wired: Factory <-> Ecosystem <-> GenePool <-> XCMRouter");

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Deployment Complete ===");
        console2.log("");
        console2.log("XCM Integration:");
        console2.log("  Mode: SIMULATION (local token transfers)");
        console2.log("  Switch to PRODUCTION for Westend Asset Hub");
        console2.log("  Production precompile: 0x0...0A0000");
        console2.log("");
        console2.log("--- Copy these addresses ---");
        console2.log("STABLECOIN=", address(stablecoin));
        console2.log("XCM_ROUTER=", address(xcmRouter));
        console2.log("EVOLUTION_ENGINE=", address(evolutionEngine));
        console2.log("FACTORY=", address(factory));
        console2.log("ECOSYSTEM=", address(ecosystem));
        console2.log("GENE_POOL=", address(genePool));
    }
}
