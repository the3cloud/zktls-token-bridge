// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Create2Deployer} from "./utils/Create2Deployer.sol";


contract DeployCreate2Deployer is Script {
    function run() external {
        vm.startBroadcast();

        Create2Deployer deployer = new Create2Deployer();

        console.log("Create2Deployer deployed at", address(deployer));

        vm.stopBroadcast();
    }
}