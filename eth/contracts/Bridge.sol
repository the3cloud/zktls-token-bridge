// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IHandler.sol";
import "./BridgeManager.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Bridge is Initializable, PausableUpgradeable, UUPSUpgradeable, BridgeManager {
    // source chain token address => token handler address
    mapping(address => address) public tokenHandlers;
    // source chain token address => destination chain id => destination chain token handler address
    mapping(address => mapping(uint16 => address)) public tokenPairs;
    // token => chainId => decimals
    mapping(address => mapping(uint16 => uint8)) public tokenDecimals;
    // deposit nonce counter
    uint256 public depositNonce;
    // Prevent replay attacks for deliveries
    mapping(uint16 => mapping(uint256 => bool)) public completed;

    event Transfer(
        uint16 destChainId,
        address destTokenHandlerAddress,
        uint256 depositNonce,
        address sender,
        address receiver,
        bytes data
    );

    event Delivery(
        uint16 srcChainId,
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
     * @notice Sets the token decimals for a token on a specific chain
     * @param tokenAddress The token address
     * @param chainId The chain ID (use local chain ID for this chain)
     * @param decimals The token decimals
     */
    function setTokenDecimals(
        address tokenAddress,
        uint16 chainId,
        uint8 decimals
    ) external onlyTokenManager() {
        tokenDecimals[tokenAddress][chainId] = decimals;
    }

    /**
     * @notice Returns the convertible amount and dust for a given source amount between two chains
     * @param token The token address
     * @param srcChainId The source chain ID
     * @param destChainId The destination chain ID
     * @param srcAmount The amount in source decimals
     * @return destAmount The amount in destination decimals
     * @return usedSrcAmount The amount of source tokens actually used
     * @return dust The unconvertible dust in source decimals
     */
    function getConvertibleAmount(
        address token,
        uint16 srcChainId,
        uint16 destChainId,
        uint256 srcAmount
    ) public view returns (uint256 destAmount, uint256 usedSrcAmount, uint256 dust) {
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

    /**
     * @notice Initiates a cross-chain token transfer
     * @param destChainId The destination chain ID
     * @param tokenAddress The source token address
     * @param amount The amount of tokens to transfer (in source decimals)
     * @param receiver The address to receive tokens on the destination chain
     */
    function transfer(
        uint16 destChainId,
        address tokenAddress,
        uint256 amount,
        address receiver
    ) external payable whenNotPaused returns (bytes memory handlerResponse) {
        require(tokenHandlers[tokenAddress] != address(0), "Token handler not set");
        require(tokenPairs[tokenAddress][destChainId] != address(0), "Token pair not set");

        (uint256 destAmount, uint256 usedSrcAmount, ) = getConvertibleAmount(
            tokenAddress,
            uint16(block.chainid),
            destChainId,
            amount
        );
        require(usedSrcAmount > 0, "Amount too small to convert");

        address handlerAddress = tokenHandlers[tokenAddress];

        IERC20(tokenAddress).transferFrom(msg.sender, handlerAddress, usedSrcAmount);

        IHandler handler = IHandler(handlerAddress);
        bytes memory data = abi.encode(tokenAddress, usedSrcAmount, receiver, destAmount);
        handlerResponse = handler.handleTransfer(data);

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
        uint16 srcChainId,
        uint256 depositNonce_,
        address receiver,
        address handlerAddress,
        bytes calldata data
        // bytes calldata proofBytes
    ) external whenNotPaused {
        // Prevent replay
        require(!completed[srcChainId][depositNonce_], "Delivery already completed");
        completed[srcChainId][depositNonce_] = true;

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
        uint16 destChainId,
        address destHandlerAddress
    ) external onlyTokenManager() {
        tokenPairs[srcTokenAddress][destChainId] = destHandlerAddress;
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