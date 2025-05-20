// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {stdToml} from "forge-std/StdToml.sol";

import {Forge} from "./Forge.sol";

contract Config {

    struct EOAConfig {
        address create2Deployer;
        address bridgeOwner;
        address bridgeTokenManager;
        address bridgeVerifier;
        address handlerAdmin;
        address handlerManager;
    }

    struct BridgeContracts {
        address proxy;
        address impl;
    }

    struct HandlerContracts {
        string contractName;
        address contractAddress;
    }

    struct TomlConfig {
        EOAConfig eoa;
        BridgeContracts bridge;
        HandlerContracts[] handlers;
    }

    function configPath() public view returns (string memory) {
        VmSafe vm = Forge.safeVm();
        return string(abi.encodePacked("config/", vm.envString("DEPLOY_CONFIG"), ".toml"));
    }

    function loadTomlConfig() public view returns (TomlConfig memory tomlConfig) {
        VmSafe vm = Forge.safeVm();
        string memory file = vm.readFile("config/anvil.toml");
        bytes memory data = vm.parseToml(file);
        tomlConfig = abi.decode(data, (TomlConfig));
    }

    function getEOAConfig() public view returns (EOAConfig memory eoaConfig) {
        VmSafe vm = Forge.safeVm();

        string memory file = vm.readFile(configPath());

        eoaConfig.create2Deployer = stdToml.readAddress(file, "$.eoa.create2_deployer");
        eoaConfig.bridgeOwner = stdToml.readAddress(file, "$.eoa.bridge_owner");
        eoaConfig.bridgeTokenManager = stdToml.readAddress(file, "$.eoa.bridge_token_manager");
        eoaConfig.bridgeVerifier = stdToml.readAddress(file, "$.eoa.bridge_verifier");
        eoaConfig.handlerAdmin = stdToml.readAddress(file, "$.eoa.handler_admin");
        eoaConfig.handlerManager = stdToml.readAddress(file, "$.eoa.handler_manager");
    }

    function getBridgeContractsInfo() public view returns (BridgeContracts memory bridgeContracts) {
        VmSafe vm = Forge.safeVm();

        string memory file = vm.readFile(configPath());

        bridgeContracts.proxy = stdToml.readAddress(file, "$.bridge.proxy");
        bridgeContracts.impl = stdToml.readAddress(file, "$.bridge.impl");
    }

    function getHandlerContractsInfo(string memory handlerName) public view returns (HandlerContracts memory handlerContracts) {
        VmSafe vm = Forge.safeVm();

        string memory file = vm.readFile(configPath());
        string memory contractPath = string.concat("$.", handlerName, ".contract");
        handlerContracts.contractAddress = stdToml.readAddress(file, contractPath);
    }
}