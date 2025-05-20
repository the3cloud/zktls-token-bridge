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
    BridgeContracts bridgeContracts;

    function run() external {

        eoaConfig = getEOAConfig();
        bridgeContracts = getBridgeContractsInfo();
        Create2Deployer deployer = Create2Deployer(eoaConfig.create2Deployer);
        vm.startBroadcast();
        // Deploy ERC20Handler
        address handlerAddress = deployer.deploy(
            keccak256(abi.encodePacked("ERC20Handler")), // salt
            type(ERC20Handler).creationCode, // contract bytecode
            abi.encode( // constructor args
                eoaConfig.handlerAdminAddress,
                eoaConfig.handlerManagerAddress,
                bridgeContracts.proxyAddress
            )
        );
        console.log("ERC20Handler deployed at:", handlerAddress);
        addDeployedContract("ERC20Handler", handlerAddress, handlerAddress);
        // save handler address to deploy config
        saveHandlerDeployInfo(configPath(), "ERC20Handler");
        vm.stopBroadcast();
    }
}