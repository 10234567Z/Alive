// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ecosystem} from "../src/Ecosystem.sol";

contract Deposit is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address stablecoin = vm.envAddress("STABLECOIN");
        address ecosystem = vm.envAddress("ECOSYSTEM");
        uint256 amount = vm.envUint("AMOUNT");

        vm.startBroadcast(pk);

        IERC20(stablecoin).approve(ecosystem, amount);
        Ecosystem(ecosystem).deposit(amount);

        console2.log("Deposited", amount / 1e6, "USDC");
        vm.stopBroadcast();
    }
}
