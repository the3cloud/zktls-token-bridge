// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TestToken} from "../contracts/TestToken.sol";

contract DeployTestToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy TestToken with initial parameters
        TestToken token = new TestToken(
            "Test Token",
            "TEST",
            1000000 * 10**18  // 1 million tokens with 18 decimals
        );

        console.log("TestToken deployed at:", address(token));

        vm.stopBroadcast();
    }
}
