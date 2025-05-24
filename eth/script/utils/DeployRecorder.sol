// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// import {Config} from "./Config.sol";

import {stdToml} from "forge-std/StdToml.sol";
import {Forge} from "./Forge.sol";
import {Config} from "./DeployConfig.sol";
import {console} from "forge-std/console.sol";

contract DeployRecorder is Config {
    mapping(string => uint256) public handlerIndex;
    HandlerContract[] public handlers;
    BridgeContract public bridge;

    function addDeployedContract(string memory name, address implAddress, address proxyAddress) public {
        if (keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked("Bridge"))) {
            bridge = BridgeContract({impl: implAddress, proxy: proxyAddress});
        } else {
            if (handlerIndex[name] == 0) {
                uint256 index = handlers.length;
                handlers.push(HandlerContract({contractName: name, contractAddress: implAddress}));
                handlerIndex[name] = index;
            } else {
                handlers[handlerIndex[name]] = HandlerContract({contractName: name, contractAddress: implAddress});
            }
        }
    }

    function saveCreate2Deployer(string memory path, address create2Deployer) public {
        string memory deployStr = Forge.safeVm().toString(create2Deployer);
        stdToml.write(deployStr, path, ".deploy.create2_deployer_address");
    }

    function _restoreEoaConfig() internal returns (string memory deployStr) {
        EOAConfig memory eoaConfig = getEOAConfig();
        deployStr = stdToml.serialize("eoa", "create2_deployer", Strings.toHexString(eoaConfig.create2Deployer));
        deployStr = stdToml.serialize("eoa", "bridge_owner", Strings.toHexString(eoaConfig.bridgeOwner));
        deployStr = stdToml.serialize("eoa", "bridge_token_manager", Strings.toHexString(eoaConfig.bridgeTokenManager));
        deployStr = stdToml.serialize("eoa", "bridge_verifier", Strings.toHexString(eoaConfig.bridgeVerifier));
        deployStr = stdToml.serialize("eoa", "handler_admin", Strings.toHexString(eoaConfig.handlerAdmin));
        deployStr = stdToml.serialize("eoa", "handler_manager", Strings.toHexString(eoaConfig.handlerManager));
        deployStr = stdToml.serialize("eoa", "handlers_count", Strings.toString(eoaConfig.handlerCount));
    }

    function _restoreBridgeDeployInfo() internal returns (string memory deployStr) {
        deployStr = stdToml.serialize("bridge", "proxy", Strings.toHexString(bridge.proxy));
        deployStr = stdToml.serialize("bridge", "impl", Strings.toHexString(bridge.impl));
    }

    function saveBridgeDeployInfo(string memory path) public returns (string memory deployStr) {
        string memory eoaDeployStr = _restoreEoaConfig();
        deployStr = _restoreBridgeDeployInfo();
        stdToml.write(eoaDeployStr, path, ".eoa");
        stdToml.write(deployStr, path, ".bridge");
    }

    function saveHandlerDeployInfo(string memory path, uint256 handlerCount) public {
        // we have to mannually populate a valid json string when handlers need to be saved
        string memory eoaDeployStr = _restoreEoaConfig();
        string memory bridgeDeployStr = _restoreBridgeDeployInfo();

        string[] memory items = new string[](handlerCount);
        string memory itemStr = "";

        for (uint256 i = 0; i < handlerCount; i++) {
            string memory itemIdx = string.concat(".handler[", Strings.toString(i), "]");
            string memory item = stdToml.serialize(itemIdx, "contractName", handlers[i].contractName);
            item = stdToml.serialize(itemIdx, "contractAddress", Strings.toHexString(handlers[i].contractAddress));

            items[i] = item;
            itemStr = string.concat(itemStr, item);
            if (i < handlerCount - 1) {
                itemStr = string.concat(itemStr, ",");
            }
        }

        string memory deployStr = string.concat(
            "{ ", '"eoa"', ":", eoaDeployStr, ',"bridge"', ":", bridgeDeployStr, ',"handlers"', ":[", itemStr, "]}"
        );
        stdToml.write(deployStr, path);
    }
}
