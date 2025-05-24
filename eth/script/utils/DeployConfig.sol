// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {stdToml} from "forge-std/StdToml.sol";

import {Forge} from "./Forge.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Config {
    using stdToml for string;

    struct EOAConfig {
        address bridgeOwner;
        address bridgeTokenManager;
        address bridgeVerifier;
        address create2Deployer;
        address handlerAdmin;
        address handlerManager;
        uint256 handlerCount;
    }

    struct BridgeContract {
        address proxy;
        address impl;
    }

    struct HandlerContract {
        string contractName;
        address contractAddress;
    }

    struct TomlConfig {
        EOAConfig eoa;
        BridgeContract bridge;
        HandlerContract[] handlers;
    }

    function configPath() public view returns (string memory) {
        VmSafe vm = Forge.safeVm();
        return string(abi.encodePacked("config/", vm.envString("DEPLOY_CONFIG"), ".toml"));
    }

    function loadTomlConfig() public view returns (TomlConfig memory tomlConfig) {
        VmSafe vm = Forge.safeVm();
        string memory file = vm.readFile(configPath());
        bytes memory data = file.parseRaw(".");
        tomlConfig = abi.decode(data, (TomlConfig));
    }

    function getEOAConfig() public view returns (EOAConfig memory eoaConfig) {
        VmSafe vm = Forge.safeVm();

        string memory file = vm.readFile(configPath());

        eoaConfig.bridgeOwner = stdToml.readAddress(file, "$.eoa.bridge_owner");
        eoaConfig.bridgeTokenManager = stdToml.readAddress(file, "$.eoa.bridge_token_manager");
        eoaConfig.bridgeVerifier = stdToml.readAddress(file, "$.eoa.bridge_verifier");
        eoaConfig.create2Deployer = stdToml.readAddress(file, "$.eoa.create2_deployer");
        eoaConfig.handlerAdmin = stdToml.readAddress(file, "$.eoa.handler_admin");
        eoaConfig.handlerManager = stdToml.readAddress(file, "$.eoa.handler_manager");
        eoaConfig.handlerCount = stdToml.readUint(file, "$.eoa.handlers_count");
    }

    function getBridgeContractsInfo() public view returns (BridgeContract memory bridgeContracts) {
        VmSafe vm = Forge.safeVm();
        string memory file = vm.readFile(configPath());
        bridgeContracts.proxy = stdToml.readAddress(file, "$.bridge.proxy");
        bridgeContracts.impl = stdToml.readAddress(file, "$.bridge.impl");
    }

    function getHandlerContractsInfo(uint256 handlerCount)
        public
        view
        returns (HandlerContract[] memory handlerContracts)
    {
        VmSafe vm = Forge.safeVm();

        string memory file = vm.readFile(configPath());
        handlerContracts = new HandlerContract[](handlerCount);

        for (uint256 i = 0; i < 2; i++) {
            string memory contractAddressPath = string.concat("$.handlers[", Strings.toString(i), "].contractAddress");
            string memory contractNamePath = string.concat("$.handlers[", Strings.toString(i), "].contractName");
            handlerContracts[i].contractName = stdToml.readString(file, contractNamePath);
            handlerContracts[i].contractAddress = stdToml.readAddress(file, contractAddressPath);
        }
    }
}
