// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./BridgeManager.sol";

contract Bridge is Initializable, PausableUpgradeable, UUPSUpgradeable, BridgeManager {
    mapping(address => bool) public registeredHandlers;
    uint256 public messageNonce;
    mapping(uint16 => mapping(uint256 => bool)) public completedMessages;

    event MessageSent(
        address indexed handler,
        uint16 destChainId,
        uint256 messageNonce,
        bytes message
    );

    event MessageDelivered(
        address indexed handler,
        uint16 srcChainId,
        uint256 messageNonce,
        bytes message
    );

    function initialize(
        address initialOwner,
        address _tokenManager
    ) initializer public {
        __BridgeManager_init(initialOwner, _tokenManager);
        __Pausable_init();
        __UUPSUpgradeable_init();
    }

    function registerHandler(address handler) external onlyTokenManager {
        registeredHandlers[handler] = true;
    }

    function unregisterHandler(address handler) external onlyTokenManager {
        registeredHandlers[handler] = false;
    }

    function sendMessage(
        uint16 destChainId,
        bytes calldata message
    ) external whenNotPaused returns (uint256) {
        require(registeredHandlers[msg.sender], "Handler not registered");

        messageNonce++;
        
        emit MessageSent(
            msg.sender,
            destChainId,
            messageNonce,
            message
        );

        return messageNonce;
    }

    function deliverMessage(
        uint16 srcChainId,
        uint256 messageNonce_,
        address handler,
        bytes calldata message
    ) external whenNotPaused {
        require(registeredHandlers[handler], "Handler not registered");
        require(!completedMessages[srcChainId][messageNonce_], "Message already delivered");

        completedMessages[srcChainId][messageNonce_] = true;

        emit MessageDelivered(
            handler,
            srcChainId,
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
}