// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

contract Create2Deployer {
    function deploy(bytes32 salt_, bytes memory bytecode_, bytes memory args_) public payable returns (address) {
        return Create2.deploy(msg.value, salt_, abi.encodePacked(bytecode_, args_));
    }

    function computeAddress(bytes32 salt_, bytes memory bytecode_, bytes memory args_) public view returns (address) {
        return Create2.computeAddress(salt_, keccak256(abi.encodePacked(bytecode_, args_)));
    }
}