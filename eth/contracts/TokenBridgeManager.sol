// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract TokenBridgeManager is Initializable, AccessManagedUpgradeable {
    address public relayer;
    address public tokenManager;

    function __TokenBridgeManager_init(address initialOwner, address _relayer, address _tokenManager) internal onlyInitializing {
        __AccessManaged_init(initialOwner);
        relayer = _relayer;
        tokenManager = _tokenManager;
    }

    error OnlyRelayer();
    error OnlyTokenManager();

    modifier onlyRelayer() {
        if (msg.sender != relayer) {
            revert OnlyRelayer();
        }
        _;
    }

    modifier onlyTokenManager() {
        if (msg.sender != tokenManager) {
            revert OnlyTokenManager();
        }
        _;
    }

    function setRelayer(address _relayer) external restricted {
        relayer = _relayer;
    }

    function setTokenManager(address _tokenManager) external restricted {
        tokenManager = _tokenManager;
    }
}
