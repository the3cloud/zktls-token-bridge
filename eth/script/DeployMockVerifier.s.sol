// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {MockVerifier} from "../contracts/mocks/MockVerifier.sol";

contract DeployMockVerifier is Script {
    function run() external {
        vm.startBroadcast();

        MockVerifier verifier = new MockVerifier();

        console.log("Mocked verifier deployed at", address(verifier));

        vm.stopBroadcast();
    }
}
