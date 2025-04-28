// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IHandler.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}


/**
 * @title ERC20Handler
 * @dev Generic ERC20 token handler for ERC20 token transfers and deliveries
 */
contract ERC20Handler is IHandler, Ownable {
    constructor(address initialOwner) Ownable(initialOwner) {}
    using SafeERC20 for IERC20;

    // token address => is locked (true) or burned (false)
    mapping(address => bool) public tokenLockStatus;
    // token address => is paused
    mapping(address => bool) public tokenPaused;

    event TokenLocked(address indexed token, address indexed sender, uint256 amount);
    event TokenUnlocked(address indexed token, address indexed receiver, uint256 amount);
    event TokenBurned(address indexed token, address indexed sender, uint256 amount);
    event TokenMinted(address indexed token, address indexed receiver, uint256 amount);

    /**
     * @notice Sets the lock status for a token
     * @param tokenAddress The token address
     * @param isLocked Whether the token should be locked (true) or burned (false)
     */
    function setTokenLockStatus(address tokenAddress, bool isLocked) external onlyOwner {
        tokenLockStatus[tokenAddress] = isLocked;
    }

    /**
     * @notice Sets the pause status for a token
     * @param tokenAddress The token address
     * @param isPaused Whether the token should be paused
     */
    function setTokenPaused(address tokenAddress, bool isPaused) external onlyOwner {
        tokenPaused[tokenAddress] = isPaused;
    }

    /**
     * @notice Handles the token transfer operation on the source chain
     * @param destChainId The destination chain ID
     * @param sender The address initiating the transfer
     * @param data The encoded data containing token address and amount
     * @return handlerResponse The response from the handler
     */
    function handleTransfer(
        uint8 destChainId,
        address sender,
        bytes calldata data
    ) external override returns (bytes memory handlerResponse) {
        (address tokenAddress, uint256 amount, ) = abi.decode(data, (address, uint256, address));
        require(!tokenPaused[tokenAddress], "Token is paused");

        IERC20 token = IERC20(tokenAddress);
        
        if (tokenLockStatus[tokenAddress]) {
            // Lock tokens
            token.safeTransferFrom(sender, address(this), amount);
            emit TokenLocked(tokenAddress, sender, amount);
        } else {
            // Burn tokens
            token.safeTransferFrom(sender, address(this), amount);
            emit TokenBurned(tokenAddress, sender, amount);
        }

        return abi.encode(true);
    }

    /**
     * @notice Handles the token delivery operation on the destination chain
     * @param receiver The address receiving the tokens
     * @param data The encoded data containing token address and amount
     * @return success Whether the delivery was successful
     */
    function handleDelivery(
        address receiver,
        bytes calldata data
    ) external override returns (bool success) {
        (address tokenAddress, uint256 amount, ) = abi.decode(data, (address, uint256, address));
        require(!tokenPaused[tokenAddress], "Token is paused");
 
        if (tokenLockStatus[tokenAddress]) {
            // Unlock tokens
            IERC20 token = IERC20(tokenAddress);
            token.safeTransfer(receiver, amount);
            emit TokenUnlocked(tokenAddress, receiver, amount);
        } else {
            // Mint tokens
            IMintableERC20(tokenAddress).mint(receiver, amount);
            emit TokenMinted(tokenAddress, receiver, amount);
        }

        return true;
    }
} 