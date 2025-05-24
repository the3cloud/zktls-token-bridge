// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBridge {
    function sendMessage(uint256 destChainId, address destHandler, bytes calldata message) external returns (uint256);
}
