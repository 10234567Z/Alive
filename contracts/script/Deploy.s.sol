// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Ecosystem} from "../src/Ecosystem.sol";
import {Creature} from "../src/Creature.sol";
import {CreatureFactory} from "../src/CreatureFactory.sol";
import {GenePool} from "../src/GenePool.sol";
import {MockStablecoin} from "../test/mocks/MockStablecoin.sol";
import {MockXCM} from "../test/mocks/MockXCM.sol";
import {MockEvolutionEngine} from "../test/mocks/MockEvolutionEngine.sol";

/// @title Deploy
/// @notice Foundry deployment script for the ALIVE Protocol.
///         Deploys all contracts in the correct order, wires circular
///         dependencies, and mints initial stablecoin supply for demo.
///
///         Deploy Order:
///         1. MockStablecoin (testnet USDC)
///         2. MockXCM (XCM precompile stand-in)
///         3. MockEvolutionEngine (PVM engine stand-in)
///         4. CreatureFactory(stablecoin, xcmPrecompile)
///         5. Ecosystem(stablecoin, factory, epochDuration)
///         6. GenePool(ecosystem, factory, evolutionEngine,
///            survivalThreshold, deathThreshold, mutationRate,
///            maxPopulation, seeder)
///         7. Wire: factory.setEcosystem(), factory.setGenePool(),
///            ecosystem.setGenePool()
contract Deploy is Script {
    // ----- Config -----
    uint256 constant EPOCH_DURATION = 100; // blocks per epoch
    uint256 constant SURVIVAL_THRESHOLD = 3000; // top 30% survive
    uint256 constant DEATH_THRESHOLD = 2000; // bottom 20% die
    uint256 constant MUTATION_RATE = 1000; // 10%
    uint256 constant MAX_POPULATION = 100; // max creatures
    uint256 constant INITIAL_MINT = 1_000_000e6; // 1M USDC (6 decimals)

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

        // ---- Step 2: Deploy MockXCM ----
        MockXCM xcm = new MockXCM();
        console2.log("2. MockXCM:", address(xcm));

        // ---- Step 3: Deploy MockEvolutionEngine ----
        MockEvolutionEngine evolutionEngine = new MockEvolutionEngine();
        console2.log("3. MockEvolutionEngine:", address(evolutionEngine));

        // ---- Step 4: Deploy CreatureFactory ----
        CreatureFactory factory = new CreatureFactory(
            address(stablecoin),
            address(xcm)
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
        console2.log("7. Wired: Factory <-> Ecosystem <-> GenePool");

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Deployment Complete ===");
        console2.log("");
        console2.log("--- Copy these addresses ---");
        console2.log("STABLECOIN=", address(stablecoin));
        console2.log("XCM=", address(xcm));
        console2.log("EVOLUTION_ENGINE=", address(evolutionEngine));
        console2.log("FACTORY=", address(factory));
        console2.log("ECOSYSTEM=", address(ecosystem));
        console2.log("GENE_POOL=", address(genePool));
    }
}
