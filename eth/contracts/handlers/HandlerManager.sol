// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract HandlerManager is Initializable, AccessManagedUpgradeable {
    address public tokenManager;
    address public bridge;

    error OnlyTokenManager();
    error OnlyBridge();

    function __HandlerManager_init(
        address initialOwner,
        address _tokenManager,
        address _bridge
    ) internal onlyInitializing {
        __AccessManaged_init(initialOwner);
        tokenManager = _tokenManager;
        bridge = _bridge;
    }

    modifier onlyTokenManager() {
        if (msg.sender != tokenManager) {
            revert OnlyTokenManager();
        }
        _;
    }

    modifier onlyBridge() {
        if (msg.sender != bridge) {
            revert OnlyBridge();
        }
        _;
    }

    function setTokenManager(address _tokenManager) external restricted {
        tokenManager = _tokenManager;
    }

    function setBridge(address _bridge) external restricted {
        bridge = _bridge;
    }
}