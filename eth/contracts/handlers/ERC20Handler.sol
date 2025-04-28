// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IHandler.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";


/**
 * @title ERC20Handler
 * @dev Generic ERC20 token handler for ERC20 token transfers and deliveries
 */
contract ERC20Handler is IHandler, Ownable {
    using SafeERC20 for IERC20;

    address public bridge;

    // token address => is locked (true) or burned (false)
    mapping(address => bool) public tokenLockStatus;
    // token address => is paused
    mapping(address => bool) public tokenPaused;

    event TokenLocked(address indexed token, address indexed sender, uint256 amount);
    event TokenUnlocked(address indexed token, address indexed receiver, uint256 amount);
    event TokenBurned(address indexed token, address indexed sender, uint256 amount);
    event TokenMinted(address indexed token, address indexed receiver, uint256 amount);

    constructor(address initialOwner, address bridgeAddress) Ownable(initialOwner) {
        bridge = bridgeAddress;
    }

    modifier onlyBridge() {
        require(msg.sender == bridge, "Only bridge can call");
        _;
    }

    function setBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
    }

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
     * @param sender The address initiating the transfer
     * @param data The encoded data containing token address and amount
     * @return handlerResponse The response from the handler
     */
    function handleTransfer(
        address sender,
        bytes calldata data
    ) external override onlyBridge returns (bytes memory handlerResponse) {
        (address tokenAddress, uint256 amount, ) = abi.decode(data, (address, uint256, address));
        require(!tokenPaused[tokenAddress], "Token is paused");

        if (tokenLockStatus[tokenAddress]) {
            // Lock tokens
            IERC20 token = IERC20(tokenAddress);
            token.safeTransferFrom(sender, address(this), amount);
            emit TokenLocked(tokenAddress, sender, amount);
        } else {
            // Burn tokens
            ERC20Burnable(tokenAddress).burn(amount);
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
    ) external override onlyBridge returns (bool success) {
        (address tokenAddress, uint256 amount, ) = abi.decode(data, (address, uint256, address));
        require(!tokenPaused[tokenAddress], "Token is paused");
 
        if (tokenLockStatus[tokenAddress]) {
            // Unlock tokens
            IERC20 token = IERC20(tokenAddress);
            token.safeTransfer(receiver, amount);
            emit TokenUnlocked(tokenAddress, receiver, amount);
        } else {
            // Mint tokens
            IERC4626(tokenAddress).mint(amount, receiver);
            emit TokenMinted(tokenAddress, receiver, amount);
        }

        return true;
    }
} 