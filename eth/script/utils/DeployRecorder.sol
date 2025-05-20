// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// import {Config} from "./Config.sol";

import {stdToml} from "forge-std/StdToml.sol";
import {Forge} from "./Forge.sol";
import {Config} from "./DeployConfig.sol";

contract DeployRecorder is Config {

    struct DeployedContract {
        string name;
        address implAddress;
        address proxyAddress;
    }

    mapping(string => uint256) public handlerIndex;
    DeployedContract[] public handlers;
    DeployedContract public bridge;

    function addDeployedContract(string memory name, address implAddress, address proxyAddress) public {
        if (keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked("Bridge"))) {
            bridge = DeployedContract({name: name, implAddress: implAddress, proxyAddress: proxyAddress});
        } else {
            if (handlerIndex[name] == 0) {
                uint256 index = handlers.length;
                handlers.push(DeployedContract({name: name, implAddress: implAddress, proxyAddress: proxyAddress}));
                handlerIndex[name] = index;
            } else {
                handlers[handlerIndex[name]] = DeployedContract({name: name, implAddress: implAddress, proxyAddress: proxyAddress});
            }
        }
    }

    function saveCreate2Deployer(string memory path, address create2Deployer) public {
        string memory deployStr = Forge.safeVm().toString(create2Deployer);
        stdToml.write(deployStr, path, ".deploy.create2_deployer_address");
    }

    function _restoreEoaConfigWithBridgeInfo(string memory path) internal {
       EOAConfig memory eoaConfig = getEOAConfig();
        string memory configStr =
            stdToml
                .serialize("config", '{"eoa": {}, "bridge": {}}');
        stdToml.write(configStr, path);        
        string memory deployStr = stdToml.serialize("eoa", "create2_deployer",  Strings.toHexString(eoaConfig.create2Deployer));
        deployStr = stdToml.serialize("eoa", "bridge_owner", Strings.toHexString(eoaConfig.bridgeOwner));
        deployStr = stdToml.serialize("eoa", "bridge_token_manager", Strings.toHexString(eoaConfig.bridgeTokenManager));
        deployStr = stdToml.serialize("eoa", "bridge_verifier", Strings.toHexString(eoaConfig.bridgeVerifier));
        deployStr = stdToml.serialize("eoa", "handler_admin", Strings.toHexString(eoaConfig.handlerAdmin));
        deployStr = stdToml.serialize("eoa", "handler_manager", Strings.toHexString(eoaConfig.handlerManager));
        stdToml.write(deployStr, path, ".eoa");
    }

    function saveBridgeDeployInfo(string memory path) public {
        _restoreEoaConfigWithBridgeInfo(path);
        string memory deployStr = stdToml.serialize("bridge", "proxy", Strings.toHexString(bridge.proxyAddress));
        deployStr = stdToml.serialize("bridge", "impl", Strings.toHexString(bridge.implAddress));
        stdToml.write(deployStr, path, ".bridge");
    }

    function _restoreEoaAndBridgeInfoWithHandlers(string memory path) internal {
        _restoreEoaConfigWithBridgeInfo(path);
         
    }

    function saveHandlerDeployInfo(string memory path, string memory handlerName) public {
        string memory configStr = stdToml.serialize(handlerName, '{}');
        stdToml.write(configStr, path);

        string memory deployStr = stdToml.serialize("contract", Strings.toHexString(handlers[handlerIndex[handlerName]].implAddress));
        stdToml.write(deployStr, path, string.concat(".", handlerName));
    }
}