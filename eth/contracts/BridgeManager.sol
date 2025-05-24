// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BridgeManager is Initializable, AccessManagedUpgradeable {
    address public tokenManager;

    function __BridgeManager_init(address initialOwner, address _tokenManager) internal onlyInitializing {
        __AccessManaged_init(initialOwner);
        tokenManager = _tokenManager;
    }

    error OnlyTokenManager();

    modifier onlyTokenManager() {
        if (msg.sender != tokenManager) {
            revert OnlyTokenManager();
        }
        _;
    }

    function setTokenManager(address _tokenManager) external restricted {
        tokenManager = _tokenManager;
    }
}
