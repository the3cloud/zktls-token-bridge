// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Create2Deployer} from "./utils/Create2Deployer.sol";
import {ERC20Handler} from "../contracts/handlers/ERC20Handler.sol";
import {Bridge} from "../contracts/Bridge.sol";
import {UpgradeableDeployer} from "./utils/UpgradeableDeployer.sol";

contract HandlerDeployScript is Script, UpgradeableDeployer {
    EOAConfig eoaConfig;
    BridgeContract bridgeContracts;

    function run() external {
        eoaConfig = getEOAConfig();
        bridgeContracts = getBridgeContractsInfo();
        Create2Deployer deployer = Create2Deployer(eoaConfig.create2Deployer);
        vm.startBroadcast();
        // set bridge contract info for handler deployment
        addDeployedContract("Bridge", bridgeContracts.impl, bridgeContracts.proxy);
        // Deploy ERC20Handler
        address handlerAddress = deployer.deploy(
            keccak256(abi.encodePacked("ERC20Handler")), // salt
            type(ERC20Handler).creationCode, // contract bytecode
            abi.encode( // constructor args
            eoaConfig.handlerAdmin, eoaConfig.handlerManager, bridgeContracts.proxy)
        );
        console.log("ERC20Handler deployed at:", handlerAddress);
        addDeployedContract("ERC20Handler", handlerAddress, address(0x0));
        // save handler address to deploy config
        saveHandlerDeployInfo(configPath(), 1);
        vm.stopBroadcast();
    }
}
