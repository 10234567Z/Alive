// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Ecosystem} from "../src/Ecosystem.sol";
import {ICreature} from "../src/interfaces/ICreature.sol";

contract SpawnCreatures is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address ecosystemAddr = vm.envAddress("ECOSYSTEM");
        
        vm.startBroadcast(pk);
        
        Ecosystem eco = Ecosystem(ecosystemAddr);
        
        // Create 10 diverse creatures targeting different Polkadot parachains
        // targetChainId: 0=AssetHub, 1=Moonbeam, 2=Acala, 3=Astar, 4=HydraDX, 5=Bifrost
        // (10 keeps proof_size within Polkadot Hub TestNet weight limits)
        ICreature.DNA[] memory dnaList = new ICreature.DNA[](10);
        
        // Creature 0: Conservative AMM LP on Moonbeam
        dnaList[0] = ICreature.DNA({
            targetChainId: 1, poolType: 0, allocationRatio: 5000,
            rebalanceThreshold: 500, maxSlippage: 50, yieldFloor: 300,
            riskCeiling: 3, entryTiming: 0, exitTiming: 5, hedgeRatio: 2000
        });
        
        // Creature 1: Aggressive Lending on Acala
        dnaList[1] = ICreature.DNA({
            targetChainId: 2, poolType: 1, allocationRatio: 8000,
            rebalanceThreshold: 300, maxSlippage: 100, yieldFloor: 500,
            riskCeiling: 7, entryTiming: 1, exitTiming: 3, hedgeRatio: 1000
        });
        
        // Creature 2: Balanced Staking on Bifrost (liquid staking hub)
        dnaList[2] = ICreature.DNA({
            targetChainId: 5, poolType: 2, allocationRatio: 6000,
            rebalanceThreshold: 400, maxSlippage: 75, yieldFloor: 400,
            riskCeiling: 5, entryTiming: 0, exitTiming: 4, hedgeRatio: 1500
        });
        
        // Creature 3: Vault strategy on Astar
        dnaList[3] = ICreature.DNA({
            targetChainId: 3, poolType: 3, allocationRatio: 7000,
            rebalanceThreshold: 600, maxSlippage: 30, yieldFloor: 200,
            riskCeiling: 4, entryTiming: 2, exitTiming: 6, hedgeRatio: 2500
        });
        
        // Creature 4: Stable Swap on HydraDX (Omnipool)
        dnaList[4] = ICreature.DNA({
            targetChainId: 4, poolType: 4, allocationRatio: 9000,
            rebalanceThreshold: 200, maxSlippage: 20, yieldFloor: 150,
            riskCeiling: 2, entryTiming: 0, exitTiming: 8, hedgeRatio: 3000
        });
        
        // Creature 5: Restaking aggressive on Bifrost
        dnaList[5] = ICreature.DNA({
            targetChainId: 5, poolType: 5, allocationRatio: 8500,
            rebalanceThreshold: 350, maxSlippage: 150, yieldFloor: 600,
            riskCeiling: 8, entryTiming: 1, exitTiming: 2, hedgeRatio: 500
        });
        
        // Creature 6: Low-risk AMM LP on HydraDX
        dnaList[6] = ICreature.DNA({
            targetChainId: 4, poolType: 0, allocationRatio: 4000,
            rebalanceThreshold: 800, maxSlippage: 25, yieldFloor: 200,
            riskCeiling: 2, entryTiming: 0, exitTiming: 7, hedgeRatio: 3500
        });
        
        // Creature 7: Medium Lending on Moonbeam
        dnaList[7] = ICreature.DNA({
            targetChainId: 1, poolType: 1, allocationRatio: 6500,
            rebalanceThreshold: 450, maxSlippage: 80, yieldFloor: 350,
            riskCeiling: 5, entryTiming: 2, exitTiming: 4, hedgeRatio: 1800
        });

        // Creature 8: High-freq Staking on Acala
        dnaList[8] = ICreature.DNA({
            targetChainId: 2, poolType: 2, allocationRatio: 7500,
            rebalanceThreshold: 200, maxSlippage: 60, yieldFloor: 450,
            riskCeiling: 6, entryTiming: 1, exitTiming: 2, hedgeRatio: 1200
        });

        // Creature 9: Defensive Vault on Asset Hub
        dnaList[9] = ICreature.DNA({
            targetChainId: 0, poolType: 3, allocationRatio: 3500,
            rebalanceThreshold: 900, maxSlippage: 15, yieldFloor: 100,
            riskCeiling: 1, entryTiming: 0, exitTiming: 9, hedgeRatio: 4000
        });

        eco.spawnInitialCreatures(dnaList);
        console2.log("Spawned 10 initial creatures!");
        
        vm.stopBroadcast();
    }
}
