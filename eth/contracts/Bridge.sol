// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./BridgeManager.sol";
import "./interfaces/IHandler.sol";
import "./interfaces/IVerifier.sol";

contract Bridge is
    Initializable,
    PausableUpgradeable,
    UUPSUpgradeable,
    BridgeManager
{
    // Registered handlers
    mapping(address => bool) public registeredHandlers;
    // Message sequence counter
    uint256 public messageNonce;
    // Verifier address
    address public verifier;

    // Prevent replay attacks
    mapping(uint256 => mapping(uint256 => bool)) public completedMessages;

    event MessageSent(
        uint256 fromChainId,
        address fromHandler,
        uint256 toChainId,
        address toHandler,
        uint256 nonce,
        bytes32 messageHash
    );

    event MessageSentBody(bytes message);

    event MessageDelivered(
        uint256 fromChainId,
        address indexed fromHandler,
        uint256 toChainId,
        address indexed toHandler,
        uint256 nonce,
        bytes message
    );

    function initialize(
        address initialOwner,
        address _tokenManager,
        address _verifier
    ) public initializer {
        __BridgeManager_init(initialOwner, _tokenManager);
        __Pausable_init();
        __UUPSUpgradeable_init();
        verifier = _verifier;
    }

    /**
     * @notice Register a handler
     * @param handler Handler address to register
     */
    function registerHandler(address handler) external onlyTokenManager {
        registeredHandlers[handler] = true;
    }

    /**
     * @notice Unregister a handler
     * @param handler Handler address to unregister
     */
    function unregisterHandler(address handler) external onlyTokenManager {
        registeredHandlers[handler] = false;
    }

    /**
     * @notice Send a cross-chain message
     * @param destChainId Destination chain ID
     * @param destHandler Destination handler address
     * @param message Message bytes to be sent
     * @return Message nonce
     */
    function sendMessage(
        uint256 destChainId,
        address destHandler,
        bytes calldata message
    ) external whenNotPaused returns (uint256) {
        require(registeredHandlers[msg.sender], "Handler not registered");
        require(destHandler != address(0), "Invalid destination handler");

        messageNonce++;

        emit MessageSent(
            uint256(block.chainid), // fromChainId
            msg.sender, // fromHandler
            destChainId, // toChainId
            destHandler, // toHandler
            messageNonce,
            keccak256(message)
        );

        emit MessageSentBody(message);

        return messageNonce;
    }

    /**
     * @notice Deliver a cross-chain message
     * @param srcChainId Source chain ID
     * @param srcHandler Source handler address
     * @param destHandler Destination handler address
     * @param messageNonce_ Message sequence number
     * @param message Message bytes to be delivered
     */
    function deliverMessage(
        uint256 srcChainId,
        address srcHandler,
        address destHandler,
        uint256 messageNonce_,
        bytes calldata message,
        bytes calldata proofBytes
    ) external whenNotPaused {
        require(registeredHandlers[destHandler], "Handler not registered");
        require(
            !completedMessages[srcChainId][messageNonce_],
            "Message already delivered"
        );

        // encode public inputs for the verifier
        bytes memory publicInputs = abi.encode(
            srcChainId,
            srcHandler,
            uint256(block.chainid),
            destHandler,
            messageNonce_,
            message
        );
        IProofVerifier(verifier).verifyProof(publicInputs, proofBytes);

        completedMessages[srcChainId][messageNonce_] = true;

        // Call destination handler to process token delivery
        bool success = IHandler(destHandler).handleDelivery(message);
        require(success, "Handler delivery failed");

        emit MessageDelivered(
            srcChainId,
            srcHandler,
            uint256(block.chainid),
            destHandler,
            messageNonce_,
            message
        );
    }

    function pause() external restricted {
        _pause();
    }

    function unpause() external restricted {
        _unpause();
    }

    function _authorizeUpgrade(address) internal override restricted {}

    function setVerifier(address _verifier) external restricted {
        require(_verifier != address(0), "Invalid verifier address");
        verifier = _verifier;
    }
}
