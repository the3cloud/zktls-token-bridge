// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Create2Deployer} from "./utils/Create2Deployer.sol";
import {UpgradeableDeployer} from "./utils/UpgradeableDeployer.sol";

import {Bridge} from "../contracts/Bridge.sol";

contract BridgeInitCode is Script, UpgradeableDeployer {
    EOAConfig eoaConfig;

    function run() external {
        vm.startBroadcast();

        eoaConfig = getEOAConfig();

        bytes memory initCode = abi.encodeCall(
            Bridge.initialize, (eoaConfig.bridgeOwner, eoaConfig.bridgeTokenManager, eoaConfig.bridgeVerifier)
        );
        console.logBytes(initCode);

        vm.stopBroadcast();
    }
}
