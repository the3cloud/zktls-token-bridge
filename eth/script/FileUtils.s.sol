// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Create2Deployer} from "./utils/Create2Deployer.sol";
import {UpgradeableDeployer} from "./utils/UpgradeableDeployer.sol";

import {Bridge} from "../contracts/Bridge.sol";

contract BridgeDeployScript is Script, UpgradeableDeployer {
    EOAConfig eoaConfig;
    BridgeContract savedBridge;
    BridgeContract readBridge;
    HandlerContract savedHandler1;
    HandlerContract savedHandler2;
    HandlerContract[] handlers1;

    function run() external {
        vm.startBroadcast();

        eoaConfig = getEOAConfig();
        console.log("eoaConfig.bridgeOwner", eoaConfig.bridgeOwner);
        console.log("eoaConfig.bridgeTokenManager", eoaConfig.bridgeTokenManager);
        console.log("eoaConfig.bridgeVerifier", eoaConfig.bridgeVerifier);
        console.log("eoaConfig.create2Deployer", eoaConfig.create2Deployer);
        console.log("eoaConfig.handlerAdmin", eoaConfig.handlerAdmin);
        console.log("eoaConfig.handlerManager", eoaConfig.handlerManager);
        console.log("eoaConfig.handlerCount", eoaConfig.handlerCount);
        // save bridge contract info
        savedBridge = BridgeContract({
            proxy: address(0xB878a321BcB64b467226440D169Af3B42b641122),
            impl: address(0xee9334dE884B32939d07bb922e8Cf4927e642233)
        });
        addDeployedContract("Bridge", savedBridge.impl, savedBridge.proxy);
        saveBridgeDeployInfo(configPath());
        // read saved bridge contract info
        readBridge = getBridgeContractsInfo();
        console.log("readBridge.proxy", readBridge.proxy);
        console.log("readBridge.impl", readBridge.impl);
        // save handler contract info
        savedHandler1 = HandlerContract({
            contractName: "GeneticHandler1",
            contractAddress: address(0xeE9334dE884b32939d07bB922E8cf4927e6466b6)
        });
        savedHandler2 = HandlerContract({
            contractName: "GeneticHandler2",
            contractAddress: address(0xEe9334DE884b32939d07bB922e8Cf4927e646688)
        });
        addDeployedContract("GeneticHandler1", savedHandler1.contractAddress, address(0x0));
        addDeployedContract("GeneticHandler2", savedHandler2.contractAddress, address(0x0));

        saveHandlerDeployInfo(configPath(), eoaConfig.handlerCount);
        handlers1 = getHandlerContractsInfo(eoaConfig.handlerCount);
        for (uint256 i = 0; i < handlers1.length; i++) {
            console.log("handler.contractName", handlers1[i].contractName);
            console.log("handler.contractAddress", handlers1[i].contractAddress);
        }
        vm.stopBroadcast();
    }
}
