// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IBridgeToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function BRIDGE_ROLE() external view returns (bytes32);
}

contract TokenBridge is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    struct TokenConfig {
        bool isSupported;
        bool isBridgeToken; // true if this is a mintable token on this chain
        uint8 decimals;
        uint256 minimumAmount;
        uint256 maximumAmount;
        uint256 dailyLimit;
        uint256 dailyUsed;
        uint256 lastResetTime;
    }

    struct BridgeOperation {
        address token;
        address sender;
        address receiver;
        uint256 amount;
        uint256 targetChainId;
        uint256 nonce;
        uint256 timestamp;
    }

    address public validator;
    mapping(address => TokenConfig) public supportedTokens;
    mapping(bytes32 => bool) public processedHashes;
    mapping(address => mapping(uint256 => address)) public tokenPairs; // token address => target chain id => target token address
    uint256 public constant DAILY_LIMIT_DURATION = 24 hours;
    
    event TokenLocked(
        address indexed token,
        address indexed from,
        address indexed receiver,
        uint256 amount,
        uint256 targetChainId,
        uint256 nonce,
        bytes32 operationHash
    );
    
    event TokenMinted(
        address indexed token,
        address indexed to,
        uint256 amount,
        uint256 sourceChainId,
        bytes32 operationHash
    );

    error InvalidToken();
    error InvalidAmount();
    error DailyLimitExceeded();
    error TransactionAlreadyProcessed();
    error UnauthorizedValidator();
    error TokenPairNotConfigured();
    error InvalidDecimals();
    error NotBridgeToken();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) initializer public {
        __Ownable_init(initialOwner);
        __Pausable_init();
        __UUPSUpgradeable_init();
    }

    modifier onlyValidator() {
        if (msg.sender != validator) revert UnauthorizedValidator();
        _;
    }

    function setValidator(address _validator) external onlyOwner {
        validator = _validator;
    }

    function configureToken(
        address token,
        bool isBridgeToken,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 dailyLimit,
        uint256[] calldata targetChainIds,
        address[] calldata targetTokens
    ) external onlyOwner {
        if (targetChainIds.length != targetTokens.length) revert InvalidToken();
        
        uint8 decimals = IERC20Metadata(token).decimals();
        
        // If this is a bridge token, ensure we have the BRIDGE_ROLE
        if (isBridgeToken) {
            try IBridgeToken(token).BRIDGE_ROLE() returns (bytes32 role) {
                // Attempt to verify or obtain BRIDGE_ROLE
                try IBridgeToken(token).grantRole(role, address(this)) {
                    // Role granted successfully
                } catch {
                    revert("Failed to obtain BRIDGE_ROLE");
                }
            } catch {
                revert("Token does not implement BRIDGE_ROLE");
            }
        }
        
        supportedTokens[token] = TokenConfig({
            isSupported: true,
            isBridgeToken: isBridgeToken,
            decimals: decimals,
            minimumAmount: minAmount,
            maximumAmount: maxAmount,
            dailyLimit: dailyLimit,
            dailyUsed: 0,
            lastResetTime: block.timestamp
        });

        for (uint256 i = 0; i < targetChainIds.length; i++) {
            tokenPairs[token][targetChainIds[i]] = targetTokens[i];
        }
    }

    function removeToken(address token) external onlyOwner {
        TokenConfig memory config = supportedTokens[token];
        if (config.isBridgeToken) {
            try IBridgeToken(token).BRIDGE_ROLE() returns (bytes32 role) {
                try IBridgeToken(token).revokeRole(role, address(this)) {
                    // Role revoked successfully
                } catch {
                    // Ignore revocation failures
                }
            } catch {
                // Ignore if BRIDGE_ROLE is not implemented
            }
        }
        delete supportedTokens[token];
    }

    function _updateDailyLimit(address token, uint256 amount) internal {
        TokenConfig storage config = supportedTokens[token];
        
        if (block.timestamp >= config.lastResetTime + DAILY_LIMIT_DURATION) {
            config.dailyUsed = amount;
            config.lastResetTime = block.timestamp;
        } else {
            config.dailyUsed += amount;
            if (config.dailyUsed > config.dailyLimit) revert DailyLimitExceeded();
        }
    }

    function _validateAmount(address token, uint256 amount) internal view {
        TokenConfig memory config = supportedTokens[token];
        if (!config.isSupported) revert InvalidToken();
        if (amount < config.minimumAmount || amount > config.maximumAmount) revert InvalidAmount();
    }

    function lockTokens(
        address token,
        address receiver,
        uint256 amount,
        uint256 targetChainId
    ) external whenNotPaused {
        if (tokenPairs[token][targetChainId] == address(0)) revert TokenPairNotConfigured();
        
        _validateAmount(token, amount);
        _updateDailyLimit(token, amount);

        BridgeOperation memory operation = BridgeOperation({
            token: token,
            sender: msg.sender,
            receiver: receiver,
            amount: amount,
            targetChainId: targetChainId,
            nonce: _generateNonce(),
            timestamp: block.timestamp
        });

        bytes32 operationHash = _hashOperation(operation);
        if (processedHashes[operationHash]) revert TransactionAlreadyProcessed();
        
        processedHashes[operationHash] = true;

        // If token is a bridge token on this chain, burn it
        if (supportedTokens[token].isBridgeToken) {
            IBridgeToken(token).burn(msg.sender, amount);
        } else {
            // Otherwise, lock it in the bridge
            require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        }
        
        emit TokenLocked(
            token,
            msg.sender,
            receiver,
            amount,
            targetChainId,
            operation.nonce,
            operationHash
        );
    }

    function mintTokens(
        address token,
        address to,
        uint256 amount,
        uint256 sourceChainId,
        bytes32 sourceChainTxHash
    ) external onlyValidator whenNotPaused {
        TokenConfig memory config = supportedTokens[token];
        if (!config.isSupported) revert InvalidToken();
        if (!config.isBridgeToken) revert NotBridgeToken();
        if (processedHashes[sourceChainTxHash]) revert TransactionAlreadyProcessed();
        
        _validateAmount(token, amount);
        _updateDailyLimit(token, amount);
        
        processedHashes[sourceChainTxHash] = true;
        
        IBridgeToken(token).mint(to, amount);
        
        emit TokenMinted(
            token,
            to,
            amount,
            sourceChainId,
            sourceChainTxHash
        );
    }

    function _generateNonce() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, block.number)));
    }

    function _hashOperation(BridgeOperation memory operation) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                operation.token,
                operation.sender,
                operation.receiver,
                operation.amount,
                operation.targetChainId,
                operation.nonce,
                operation.timestamp
            )
        );
    }

    function calculateTargetAmount(
        address sourceToken,
        uint256 sourceAmount,
        uint256 targetChainId
    ) external view returns (uint256) {
        address targetToken = tokenPairs[sourceToken][targetChainId];
        if (targetToken == address(0)) revert TokenPairNotConfigured();
        
        uint8 sourceDecimals = supportedTokens[sourceToken].decimals;
        uint8 targetDecimals = IERC20Metadata(targetToken).decimals();
        
        uint256 amount = sourceAmount;
        if (sourceDecimals > targetDecimals) {
            amount = sourceAmount / (10 ** (sourceDecimals - targetDecimals));
        } else if (sourceDecimals < targetDecimals) {
            amount = sourceAmount * (10 ** (targetDecimals - sourceDecimals));
        }
        return amount;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
} 