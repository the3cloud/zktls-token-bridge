// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IHandler.sol";
import "./BridgeManager.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./BridgeManager.sol";

contract Bridge is Initializable, PausableUpgradeable, UUPSUpgradeable, BridgeManager {
    // source chain token address => token handler address
    mapping(address => address) public tokenHandlers;
    // source chain token address => destination chain id => destination chain token handler address
    mapping(address => mapping(uint8 => address)) public tokenPairs;
    // token decimals, token address => encode bytes[] for src and dest token decimals
    mapping(address => bytes[]) public tokenDecimals;
    // deposit nonce counter
    uint256 public depositNonce;

    event Transfer(
        uint8 destChainId,
        address destTokenHandlerAddress,
        uint256 depositNonce,
        address sender,
        address receiver,
        bytes data
    );

    event Delivery(
        uint8 srcChainId,
        uint256 depositNonce,
        address receiver,
        address tokenHandler,
        bytes data
    );

    function initialize(address initialOwner, address _tokenManager) initializer public {
        __BridgeManager_init(initialOwner, _tokenManager);
        __Pausable_init();
        __UUPSUpgradeable_init();
    }

    /**
     * @notice Initiates a cross-chain token transfer
     * @param destChainId The destination chain ID
     * @param tokenAddress The source token address
     * @param amount The amount of tokens to transfer
     * @param receiver The address to receive tokens on the destination chain
     */
    function transfer(
        uint8 destChainId,
        address tokenAddress,
        uint256 amount,
        address receiver
    ) external payable whenNotPaused {
        require(tokenHandlers[tokenAddress] != address(0), "Token handler not set");
        require(tokenPairs[tokenAddress][destChainId] != address(0), "Token pair not set");

        address handlerAddress = tokenHandlers[tokenAddress];
        IHandler handler = IHandler(handlerAddress);

        bytes memory data = abi.encode(tokenAddress, amount, receiver);
        bytes memory handlerResponse = handler.handleTransfer(destChainId, msg.sender, data);

        depositNonce++;
        emit Transfer(
            destChainId,
            tokenPairs[tokenAddress][destChainId],
            depositNonce,
            msg.sender,
            receiver,
            data
        );
    }

    /**
     * @notice Delivers tokens on the destination chain
     * @param srcChainId The source chain ID
     * @param depositNonce_ The deposit nonce from the source chain
     * @param receiver The address to receive the tokens
     * @param handlerAddress The token handler address
     * @param data The encoded data containing token address and amount
     */
    function delivery(
        uint8 srcChainId,
        uint256 depositNonce_,
        address receiver,
        address handlerAddress,
        bytes calldata data
        // bytes calldata proofBytes
    ) external whenNotPaused {
        // TODO: Verify proofBytes

        IHandler handler = IHandler(handlerAddress);
        require(handler.handleDelivery(receiver, data), "Delivery failed");

        emit Delivery(srcChainId, depositNonce_, receiver, handlerAddress, data);
    }

    /***** Token Management Functions ******/

    /**
     * @notice Sets the token handler for a token
     * @param tokenAddress The token address
     * @param handlerAddress The handler address
     */
    function setTokenHandler(
        address tokenAddress,
        address handlerAddress
    ) external onlyTokenManager() {
        tokenHandlers[tokenAddress] = handlerAddress;
    }

    /**
     * @notice Sets the token pair for cross-chain transfer
     * @param srcTokenAddress The source token address
     * @param destChainId The destination chain ID
     * @param destHandlerAddress The destination handler address
     */
    function setTokenPair(
        address srcTokenAddress,
        uint8 destChainId,
        address destHandlerAddress
    ) external onlyTokenManager() {
        tokenPairs[srcTokenAddress][destChainId] = destHandlerAddress;
    }

    /**
     * @notice Sets the token decimals for a token
     * @param tokenAddress The token address
     * @param srcDecimals The source token decimals
     * @param destDecimals The destination token decimals
     */
    function setTokenDecimals(
        address tokenAddress,
        uint8 srcDecimals,
        uint8 destDecimals
    ) external onlyTokenManager() {
        tokenDecimals[tokenAddress].push(abi.encode(srcDecimals));
        tokenDecimals[tokenAddress].push(abi.encode(destDecimals));
    }

    /***** Bridge Management Functions ******/

    /**
     * @notice Pauses the bridge
     */
    function pause() external restricted {
        _pause();
    }

    /**
     * @notice Unpauses the bridge
     */
    function unpause() external restricted {
        _unpause();
    }

    function _authorizeUpgrade(address) internal override restricted {}
} 