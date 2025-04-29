// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IHandler {
    /**
     * @notice Handles the token transfer operation on the source chain
     * @param data The encoded data containing token address and amount
     * @return handlerResponse The response from the handler
     */
    function handleTransfer(
        bytes calldata data
    ) external returns (bytes memory handlerResponse);

    /**
     * @notice Handles the token delivery operation on the destination chain
     * @param receiver The address receiving the tokens
     * @param data The encoded data containing token address and amount
     * @return success Whether the delivery was successful
     */
    function handleDelivery(
        bytes calldata data
    ) external returns (bool success);
} 