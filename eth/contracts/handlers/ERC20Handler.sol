// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./HandlerManager.sol";
import "../interfaces/IBridge.sol";

contract ERC20Handler is Initializable, HandlerManager {
    using SafeERC20 for IERC20;

    /* tokens configuration */
    // src token => destination chain id => destination handler address
    mapping(address => mapping(uint16 => address)) public destHandlers;
    // src token => destination chain id => decimals
    mapping(address => mapping(uint16 => uint8)) public tokenDecimals;
    // src token => is_paused
    mapping(address => bool) public tokenPaused;
    // src token => destination chain id => max transfer limit
    mapping(address => mapping(uint16 => uint256)) public maxTransferLimit;

    event TokenLocked(
        address indexed token,
        address indexed sender,
        uint256 srcAmount,
        uint256 destAmount
    );

    event TokenUnlocked(
        address indexed token,
        address indexed receiver,
        uint256 amount
    );

    event TokenLimitUpdated(
        address indexed token,
        uint16 indexed chainId,
        uint256 maxTransferLimit
    );

    function initialize(
        address initialOwner,
        address _tokenManager,
        address _bridge
    ) initializer public {
        __HandlerManager_init(initialOwner, _tokenManager, _bridge);
    }

    function handleTransfer(
        bytes calldata data
    ) external payable onlyBridge returns (bytes memory) {
        (
            address token,
            uint16 destChainId,
            uint256 amount,
            address receiver
        ) = abi.decode(data, (address, uint16, uint256, address));

        require(!tokenPaused[token], "Token is paused");
        require(tokenDecimals[token][destChainId] > 0, "Chain not supported for token");

        (uint256 destAmount, uint256 usedSrcAmount, ) = getConvertibleAmount(
            token,
            uint16(block.chainid),
            destChainId,
            amount
        );

        require(destAmount <= maxTransferLimit[token][destChainId], "Exceeds transfer limit");

        if (token == address(0)) {
            require(msg.value == usedSrcAmount, "Invalid native token amount");
            emit TokenLocked(address(0), msg.sender, usedSrcAmount, destAmount);
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), usedSrcAmount);
            emit TokenLocked(token, msg.sender, usedSrcAmount, destAmount);
        }

        bytes memory message = abi.encode(destHandlers[token][destChainId], destAmount, receiver);
        
        // Call bridge to send the cross-chain message
        IBridge(bridge).sendMessage(destChainId, destHandlers[token][destChainId], message);

        return message;
    }

    function handleDelivery(
        bytes calldata data
    ) external onlyBridge returns (bool) {
        (
            address token,
            uint256 amount,
            address receiver
        ) = abi.decode(data, (address, uint256, address));

        if (token == address(0)) {
            require(address(this).balance >= amount, "Insufficient native token balance");
            (bool success, ) = payable(receiver).call{value: amount}("");
            require(success, "Native token transfer failed");
            emit TokenUnlocked(address(0), receiver, amount);
        } else {
            IERC20(token).safeTransfer(receiver, amount);
            emit TokenUnlocked(token, receiver, amount);
        }

        return true;
    }

    function getConvertibleAmount(
        address token,
        uint16 srcChainId,
        uint16 destChainId,
        uint256 srcAmount
    ) public view returns (
        uint256 destAmount,
        uint256 usedSrcAmount,
        uint256 dust
    ) {
        uint8 srcDecimals = tokenDecimals[token][srcChainId];
        uint8 destDecimals = tokenDecimals[token][destChainId];

        if (srcDecimals == destDecimals) {
            destAmount = srcAmount;
            usedSrcAmount = srcAmount;
            dust = 0;
        } else if (srcDecimals > destDecimals) {
            uint256 factor = 10 ** (srcDecimals - destDecimals);
            destAmount = srcAmount / factor;
            usedSrcAmount = destAmount * factor;
            dust = srcAmount - usedSrcAmount;
        } else {
            uint256 factor = 10 ** (destDecimals - srcDecimals);
            destAmount = srcAmount * factor;
            usedSrcAmount = srcAmount;
            dust = 0;
        }
    }

    /* token management */
    function addTokenSupport(
        address token,
        uint16 chainId,
        address handler,
        uint8 decimals,
        uint256 limit
    ) external onlyTokenManager {
        tokenDecimals[token][chainId] = decimals;
        destHandlers[token][chainId] = handler;
        tokenPaused[token] = false;
        maxTransferLimit[token][chainId] = limit;
    }

    function removeTokenSupport(
        address token,
        uint16 chainId
    ) external onlyTokenManager {
        delete tokenDecimals[token][chainId];
        delete destHandlers[token][chainId];
        tokenPaused[token] = false;
        maxTransferLimit[token][chainId] = 0;
    }

    function setTokenPaused(
        address token,
        bool isPaused
    ) external onlyTokenManager {
        tokenPaused[token] = isPaused;
    }

    function setTransferLimit(
        address token,
        uint16 chainId,
        uint256 limit
    ) external onlyTokenManager {
        maxTransferLimit[token][chainId] = limit;
        emit TokenLimitUpdated(token, chainId, limit);
    } 
}