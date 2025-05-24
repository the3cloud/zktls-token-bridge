// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Create2Deployer} from "./utils/Create2Deployer.sol";
import {ERC20Handler} from "../contracts/handlers/ERC20Handler.sol";
import {Bridge} from "../contracts/Bridge.sol";
import {UpgradeableDeployer} from "./utils/UpgradeableDeployer.sol";

contract PostDeploymentSetup is Script, UpgradeableDeployer {
    EOAConfig eoaConfig;
    BridgeContract bridgeContracts;

    function run() external {
        eoaConfig = getEOAConfig();
        bridgeContracts = getBridgeContractsInfo();
         
        vm.stopBroadcast();
    }
}
