// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "./TokenBridgeManager.sol";

contract BridgeToken is Initializable, ERC20Upgradeable {
    TokenBridgeManager public manager;

    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address _manager
    ) public initializer {
        __ERC20_init(name, symbol);
        manager = TokenBridgeManager(_manager);
        _mint(msg.sender, 0);
    }

    function mint(address to, uint256 amount) external {
        if (!manager.isTokenManager(msg.sender)) revert UnauthorizedAccess();
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        if (!manager.isTokenManager(msg.sender)) revert UnauthorizedAccess();
        _burn(from, amount);
    }
}

contract TokenFactory is Initializable, TokenBridgeManager {
    error InvalidSalt();
    error DeploymentFailed();
    error UnauthorizedAccess();

    event TokenDeployed(address indexed token, string name, string symbol, uint8 decimals, bytes32 salt);

    function initialize(address _manager) public initializer {
        __TokenBridgeManager_init(msg.sender, _manager);
    }

    function computeTokenAddress(
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        bytes32 salt
    ) external view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(BridgeToken).creationCode,
            abi.encode(name, symbol, decimals, address(manager))
        );
        return Create2.computeAddress(salt, keccak256(bytecode), address(this));
    }

    function deployToken(
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        bytes32 salt
    ) external restricted returns (address) {
        if (salt == bytes32(0)) revert InvalidSalt();

        bytes memory bytecode = abi.encodePacked(
            type(BridgeToken).creationCode,
            abi.encode(name, symbol, decimals, address(manager))
        );

        address newToken = Create2.deploy(0, salt, bytecode);
        if (newToken == address(0)) revert DeploymentFailed();

        emit TokenDeployed(newToken, name, symbol, decimals, salt);
        return newToken;
    }
} 