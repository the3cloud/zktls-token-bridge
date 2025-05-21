// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Create2Deployer} from "./utils/Create2Deployer.sol";
import {UpgradeableDeployer} from "./utils/UpgradeableDeployer.sol";

import {Bridge} from "../contracts/Bridge.sol";

contract BridgeDeployScript is Script, UpgradeableDeployer {
    
    EOAConfig eoaConfig;

    function run() external {
        vm.startBroadcast();
        
        eoaConfig = getEOAConfig(); 

        console.log("eoaConfig.bridgeOwner", eoaConfig.bridgeOwner);
        console.log("eoaConfig.bridgeTokenManager", eoaConfig.bridgeTokenManager);
        console.log("eoaConfig.bridgeVerifier", eoaConfig.bridgeVerifier);

        // Deploy Bridge using UUPS proxy
        (address proxyAddress, address implAddress) = deployUUPS(
            Create2Deployer(eoaConfig.create2Deployer),
            "Bridge",
            type(Bridge).creationCode,
            abi.encodeCall(
                Bridge.initialize,
                (
                    eoaConfig.bridgeOwner, 
                    eoaConfig.bridgeTokenManager, 
                    eoaConfig.bridgeVerifier
                )
            )
        );
        console.log("Bridge implementation deployed at:", implAddress);
        console.log("Bridge proxy deployed at:", proxyAddress);

        saveBridgeDeployInfo(configPath());
        vm.stopBroadcast();
    }
}