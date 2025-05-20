// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Create2Deployer} from "./Create2Deployer.sol";
import {DeployRecorder} from "./DeployRecorder.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {console} from "forge-std/console.sol";

contract UpgradeableDeployer is DeployRecorder {
    function deployProxyImplementation(Create2Deployer deployer, string memory contractName, bytes memory bytecode)
        public
        returns (address)
    {
        return deployImplementation(deployer, contractName, bytecode, bytes(""));
    }

    function deployImplementation(Create2Deployer deployer, string memory contractName, bytes memory bytecode, bytes memory args)
        public
        returns (address)
    {
        bytes32 implementationSalt = keccak256(abi.encode(contractName, "implementation"));
        address implementation = deployer.deploy(implementationSalt, bytecode, args);

        return implementation;
    }

    function deployUUPS(
        Create2Deployer deployer,
        string memory contractName,
        bytes memory bytecode,
        bytes memory args,
        uint256 amount
    ) public returns (address, address) {
        // deploy implementation
        address implementation = deployProxyImplementation(deployer, contractName, bytecode);

        // Deploy the proxy contract
        bytes32 proxySalt = keccak256(abi.encode(contractName, "proxy"));
        bytes memory deployArgs = abi.encode(implementation, args);
        address proxy = deployer.deploy{value: amount}(proxySalt, type(ERC1967Proxy).creationCode, deployArgs);

        addDeployedContract(contractName, proxy, implementation);
        
        return (proxy, implementation);
    }

    function deployUUPS(
        Create2Deployer deployer, 
        string memory contractName, 
        bytes memory bytecode, 
        bytes memory args
    ) public returns (address, address) {
        return deployUUPS(deployer, contractName, bytecode, args, 0);
    }

    function deployBeacon(Create2Deployer deployer, string memory contractName, bytes memory bytecode, address owner)
        public
        returns (address)
    {
        address implementation = deployImplementation(deployer, contractName, bytecode, bytes(""));

        bytes32 beaconSalt = keccak256(abi.encode(contractName, "beacon"));
        address beacon =
            deployer.deploy(beaconSalt, type(UpgradeableBeacon).creationCode, abi.encode(implementation, owner));

        return beacon;
    }
} 