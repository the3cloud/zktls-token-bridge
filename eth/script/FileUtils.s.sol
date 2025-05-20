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
        
        TomlConfig memory tomlConfig = loadTomlConfig();

        console.log("tomlConfig.eoa.create2Deployer", tomlConfig.eoa.create2Deployer);
        console.log("tomlConfig.eoa.bridgeOwner", tomlConfig.eoa.bridgeOwner);
        console.log("tomlConfig.eoa.bridgeTokenManager", tomlConfig.eoa.bridgeTokenManager);
        console.log("tomlConfig.eoa.bridgeVerifier", tomlConfig.eoa.bridgeVerifier);
        console.log("tomlConfig.eoa.handlerAdmin", tomlConfig.eoa.handlerAdmin);
        console.log("tomlConfig.eoa.handlerManager", tomlConfig.eoa.handlerManager);

        console.log("tomlConfig.bridge.proxy", tomlConfig.bridge.proxy);
        console.log("tomlConfig.bridge.impl", tomlConfig.bridge.impl);

        for (uint256 i = 0; i < tomlConfig.handlers.length; i++) {
            console.log("tomlConfig.handlers[i].contractName", tomlConfig.handlers[i].contractName);
            console.log("tomlConfig.handlers[i].contractAddress", tomlConfig.handlers[i].contractAddress);
        }

        // eoaConfig = getEOAConfig(); 

        // console.log("eoaConfig.bridgeOwnerAddress", eoaConfig.bridgeOwnerAddress);
        // console.log("eoaConfig.bridgeTokenManagerAddress", eoaConfig.bridgeTokenManagerAddress);
        // console.log("eoaConfig.bridgeVerifierAddress", eoaConfig.bridgeVerifierAddress);

        // addDeployedContract(
        //   "Bridge", 
        //   address(0xB878a321BCB64b467226440d169aF3B42b642293),
        //   address(0xeE9334De884b32939d07bB922E8cF4927E6466b7)
        // );

        // saveBridgeDeployInfo(configPath());


        vm.stopBroadcast();
    }
}