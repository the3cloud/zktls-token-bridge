// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridge {
    function sendMessage(
        uint16 destChainId,
        address destHandler,
        bytes calldata message
    ) external returns (uint256);
} 