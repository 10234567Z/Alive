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
        
        // Create 20 diverse creatures with different strategies
        ICreature.DNA[] memory dnaList = new ICreature.DNA[](20);
        
        // Creature 0: Conservative AMM LP
        dnaList[0] = ICreature.DNA({
            targetChainId: 1, poolType: 0, allocationRatio: 5000,
            rebalanceThreshold: 500, maxSlippage: 50, yieldFloor: 300,
            riskCeiling: 3, entryTiming: 0, exitTiming: 5, hedgeRatio: 2000
        });
        
        // Creature 1: Aggressive Lending
        dnaList[1] = ICreature.DNA({
            targetChainId: 1, poolType: 1, allocationRatio: 8000,
            rebalanceThreshold: 300, maxSlippage: 100, yieldFloor: 500,
            riskCeiling: 7, entryTiming: 1, exitTiming: 3, hedgeRatio: 1000
        });
        
        // Creature 2: Balanced Staking
        dnaList[2] = ICreature.DNA({
            targetChainId: 2, poolType: 2, allocationRatio: 6000,
            rebalanceThreshold: 400, maxSlippage: 75, yieldFloor: 400,
            riskCeiling: 5, entryTiming: 0, exitTiming: 4, hedgeRatio: 1500
        });
        
        // Creature 3: Vault strategy
        dnaList[3] = ICreature.DNA({
            targetChainId: 1, poolType: 3, allocationRatio: 7000,
            rebalanceThreshold: 600, maxSlippage: 30, yieldFloor: 200,
            riskCeiling: 4, entryTiming: 2, exitTiming: 6, hedgeRatio: 2500
        });
        
        // Creature 4: Stable Swap high allocation
        dnaList[4] = ICreature.DNA({
            targetChainId: 3, poolType: 4, allocationRatio: 9000,
            rebalanceThreshold: 200, maxSlippage: 20, yieldFloor: 150,
            riskCeiling: 2, entryTiming: 0, exitTiming: 8, hedgeRatio: 3000
        });
        
        // Creature 5: Restaking aggressive
        dnaList[5] = ICreature.DNA({
            targetChainId: 2, poolType: 5, allocationRatio: 8500,
            rebalanceThreshold: 350, maxSlippage: 150, yieldFloor: 600,
            riskCeiling: 8, entryTiming: 1, exitTiming: 2, hedgeRatio: 500
        });
        
        // Creature 6: Low-risk AMM LP
        dnaList[6] = ICreature.DNA({
            targetChainId: 1, poolType: 0, allocationRatio: 4000,
            rebalanceThreshold: 800, maxSlippage: 25, yieldFloor: 200,
            riskCeiling: 2, entryTiming: 0, exitTiming: 7, hedgeRatio: 3500
        });
        
        // Creature 7: Medium Lending
        dnaList[7] = ICreature.DNA({
            targetChainId: 3, poolType: 1, allocationRatio: 6500,
            rebalanceThreshold: 450, maxSlippage: 80, yieldFloor: 350,
            riskCeiling: 5, entryTiming: 2, exitTiming: 4, hedgeRatio: 1800
        });

        // Creature 8: High-freq Staking
        dnaList[8] = ICreature.DNA({
            targetChainId: 1, poolType: 2, allocationRatio: 7500,
            rebalanceThreshold: 200, maxSlippage: 60, yieldFloor: 450,
            riskCeiling: 6, entryTiming: 1, exitTiming: 2, hedgeRatio: 1200
        });

        // Creature 9: Defensive Vault
        dnaList[9] = ICreature.DNA({
            targetChainId: 2, poolType: 3, allocationRatio: 3500,
            rebalanceThreshold: 900, maxSlippage: 15, yieldFloor: 100,
            riskCeiling: 1, entryTiming: 0, exitTiming: 9, hedgeRatio: 4000
        });

        // Creature 10: Yield-chaser AMM
        dnaList[10] = ICreature.DNA({
            targetChainId: 3, poolType: 0, allocationRatio: 9500,
            rebalanceThreshold: 150, maxSlippage: 200, yieldFloor: 800,
            riskCeiling: 9, entryTiming: 1, exitTiming: 1, hedgeRatio: 300
        });

        // Creature 11: Stable Swap conservative
        dnaList[11] = ICreature.DNA({
            targetChainId: 1, poolType: 4, allocationRatio: 5500,
            rebalanceThreshold: 700, maxSlippage: 30, yieldFloor: 250,
            riskCeiling: 3, entryTiming: 0, exitTiming: 6, hedgeRatio: 2800
        });

        // Creature 12: Restaking moderate
        dnaList[12] = ICreature.DNA({
            targetChainId: 2, poolType: 5, allocationRatio: 6000,
            rebalanceThreshold: 500, maxSlippage: 90, yieldFloor: 400,
            riskCeiling: 6, entryTiming: 2, exitTiming: 3, hedgeRatio: 1500
        });

        // Creature 13: Micro-alloc Lending
        dnaList[13] = ICreature.DNA({
            targetChainId: 3, poolType: 1, allocationRatio: 2000,
            rebalanceThreshold: 1000, maxSlippage: 40, yieldFloor: 150,
            riskCeiling: 2, entryTiming: 0, exitTiming: 8, hedgeRatio: 4500
        });

        // Creature 14: Max-risk Staking
        dnaList[14] = ICreature.DNA({
            targetChainId: 1, poolType: 2, allocationRatio: 10000,
            rebalanceThreshold: 100, maxSlippage: 300, yieldFloor: 1000,
            riskCeiling: 10, entryTiming: 1, exitTiming: 1, hedgeRatio: 0
        });

        // Creature 15: Balanced Vault
        dnaList[15] = ICreature.DNA({
            targetChainId: 2, poolType: 3, allocationRatio: 5000,
            rebalanceThreshold: 500, maxSlippage: 50, yieldFloor: 300,
            riskCeiling: 5, entryTiming: 0, exitTiming: 5, hedgeRatio: 2500
        });

        // Creature 16: Aggressive Stable Swap
        dnaList[16] = ICreature.DNA({
            targetChainId: 3, poolType: 4, allocationRatio: 8000,
            rebalanceThreshold: 250, maxSlippage: 100, yieldFloor: 500,
            riskCeiling: 7, entryTiming: 2, exitTiming: 2, hedgeRatio: 800
        });

        // Creature 17: Hedged AMM LP
        dnaList[17] = ICreature.DNA({
            targetChainId: 1, poolType: 0, allocationRatio: 6000,
            rebalanceThreshold: 400, maxSlippage: 60, yieldFloor: 350,
            riskCeiling: 4, entryTiming: 0, exitTiming: 5, hedgeRatio: 5000
        });

        // Creature 18: Sprint Restaking
        dnaList[18] = ICreature.DNA({
            targetChainId: 2, poolType: 5, allocationRatio: 7000,
            rebalanceThreshold: 300, maxSlippage: 120, yieldFloor: 550,
            riskCeiling: 8, entryTiming: 1, exitTiming: 2, hedgeRatio: 600
        });

        // Creature 19: Ultra-safe Lending
        dnaList[19] = ICreature.DNA({
            targetChainId: 1, poolType: 1, allocationRatio: 3000,
            rebalanceThreshold: 1200, maxSlippage: 10, yieldFloor: 100,
            riskCeiling: 1, entryTiming: 0, exitTiming: 10, hedgeRatio: 4800
        });
        
        eco.spawnInitialCreatures(dnaList);
        console2.log("Spawned 20 initial creatures!");
        
        vm.stopBroadcast();
    }
}
