// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Ecosystem} from "../src/Ecosystem.sol";
import {Creature} from "../src/Creature.sol";
import {CreatureFactory} from "../src/CreatureFactory.sol";
import {GenePool} from "../src/GenePool.sol";
import {EvolutionEngine} from "../src/EvolutionEngine.sol";
import {XCMRouter} from "../src/xcm/XCMRouter.sol";

/// @title DeployProduction
/// @notice Foundry deployment script for the ALIVE Protocol on Westend Asset Hub.
///
///         This script deploys the full ALIVE stack with the REAL XCM integration
///         using the XCMRouter in PRODUCTION mode. It connects to the Polkadot Hub
///         XCM precompile at 0x0...0A0000 for actual cross-chain asset transfers.
///
///         Target Network: Westend Asset Hub (Chain ID: 420420421)
///         RPC: https://westend-asset-hub-eth-rpc.polkadot.io
///
///         Deploy:
///           PRIVATE_KEY=<key> forge script script/DeployProduction.s.sol \
///             --rpc-url https://westend-asset-hub-eth-rpc.polkadot.io \
///             --broadcast --via-ir
///
///         Prerequisites:
///           - Deployer account funded with WND (Westend DOT) for gas
///           - Stablecoin tokens available on Asset Hub (USDT asset ID 1984)
contract DeployProduction is Script {
    // ----- Westend Asset Hub Config -----
    uint32 constant ASSET_HUB_PARA_ID = 1000;         // Asset Hub parachain ID
    uint128 constant USDT_ASSET_ID = 1984;             // USDT GeneralIndex on Asset Hub
    uint128 constant USDC_ASSET_ID = 1337;             // USDC GeneralIndex on Asset Hub

    // ----- Protocol Config -----
    uint256 constant EPOCH_DURATION = 300;              // ~5 min at 1 block/sec
    uint256 constant SURVIVAL_THRESHOLD = 3000;         // top 30% survive
    uint256 constant DEATH_THRESHOLD = 2000;            // bottom 20% die
    uint256 constant MUTATION_RATE = 500;               // 5% mutation rate
    uint256 constant MAX_POPULATION = 50;               // max creatures

    function run() external {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);

        // Stablecoin address on Westend Asset Hub (ERC20 precompile for USDT)
        // On Asset Hub, pallet-assets tokens are exposed via ERC20 precompiles
        // Address format: 0xFFFFFFFF + asset_id_hex
        address stablecoinAddr = vm.envOr(
            "STABLECOIN_ADDRESS",
            address(0) // Set via env if not using the computed address
        );

        console2.log("=== ALIVE Protocol - Production Deployment ===");
        console2.log("Network: Westend Asset Hub");
        console2.log("Deployer:", deployer);
        console2.log("");

        vm.startBroadcast(deployerPK);

        // ---- Step 1: Deploy XCMRouter (PRODUCTION mode) ----
        XCMRouter xcmRouter = new XCMRouter(
            XCMRouter.Mode.PRODUCTION,
            ASSET_HUB_PARA_ID
        );
        console2.log("1. XCMRouter (PRODUCTION):", address(xcmRouter));
        console2.log("   XCM Precompile: 0x00000000000000000000000000000000000a0000");

        // Register stablecoin assets
        if (stablecoinAddr != address(0)) {
            xcmRouter.registerAsset(stablecoinAddr, USDT_ASSET_ID);
            console2.log("   Registered USDT:", stablecoinAddr, "-> GeneralIndex", USDT_ASSET_ID);
        }

        // ---- Step 2: Deploy EvolutionEngine ----
        EvolutionEngine evolutionEngine = new EvolutionEngine();
        console2.log("2. EvolutionEngine:", address(evolutionEngine));

        // ---- Step 3: Deploy CreatureFactory ----
        CreatureFactory factory = new CreatureFactory(
            stablecoinAddr != address(0) ? stablecoinAddr : address(1), // placeholder if no stablecoin set
            address(xcmRouter)
        );
        console2.log("3. CreatureFactory:", address(factory));

        // ---- Step 4: Deploy Ecosystem ----
        Ecosystem ecosystem = new Ecosystem(
            stablecoinAddr != address(0) ? stablecoinAddr : address(1),
            address(factory),
            EPOCH_DURATION
        );
        console2.log("4. Ecosystem:", address(ecosystem));

        // ---- Step 5: Deploy GenePool ----
        GenePool genePool = new GenePool(
            address(ecosystem),
            address(factory),
            address(evolutionEngine),
            SURVIVAL_THRESHOLD,
            DEATH_THRESHOLD,
            MUTATION_RATE,
            MAX_POPULATION,
            deployer
        );
        console2.log("5. GenePool:", address(genePool));

        // ---- Step 6: Wire dependencies ----
        factory.setEcosystem(address(ecosystem));
        factory.setGenePool(address(genePool));
        ecosystem.setGenePool(address(genePool));
        console2.log("6. Wired: Factory <-> Ecosystem <-> GenePool");

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Production Deployment Complete ===");
        console2.log("");
        console2.log("XCM Integration:");
        console2.log("  Mode: PRODUCTION (real XCM precompile)");
        console2.log("  Precompile: 0x00000000000000000000000000000000000a0000");
        console2.log("  Asset Hub ParaId:", ASSET_HUB_PARA_ID);
        console2.log("");
        console2.log("--- Contract Addresses ---");
        console2.log("XCM_ROUTER=", address(xcmRouter));
        console2.log("EVOLUTION_ENGINE=", address(evolutionEngine));
        console2.log("FACTORY=", address(factory));
        console2.log("ECOSYSTEM=", address(ecosystem));
        console2.log("GENE_POOL=", address(genePool));
    }
}
