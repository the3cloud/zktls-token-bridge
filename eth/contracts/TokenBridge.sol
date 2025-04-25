// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "./TokenFactory.sol";
import "./TokenBridgeManager.sol";
import "./interfaces/IVerifier.sol";

interface IMintableBurnableToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

contract TokenBridge is Initializable, PausableUpgradeable, UUPSUpgradeable, TokenBridgeManager {
    struct TokenConfig {
        bool isSupported;
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
        uint256 sourceChainId;
    }

    TokenFactory public tokenFactory;
    IProofVerifier public verifier;

    mapping(address => TokenConfig) public supportedTokens;
    mapping(bytes32 => bytes) public operationProofs; // operationHash => proof bytes
    mapping(address => mapping(uint256 => address)) public tokenPairs;
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

    event OperationRelayed(
        bytes32 indexed operationHash,
        uint256 sourceChainId,
        uint256 targetChainId
    );

    error InvalidToken();
    error InvalidAmount();
    error DailyLimitExceeded();
    error TransactionAlreadyProcessed();
    error UnauthorizedValidator();
    error TokenPairNotConfigured();
    error InvalidDecimals();
    error NotMintableBurnable();
    error TokenAlreadyExists();
    error TokenDeploymentFailed();
    error InvalidSalt();
    error InvalidFactory();
    error InvalidVerifier();
    error InvalidProof();
    error InvalidOperation();
    error UnauthorizedAccess();

    function initialize(address initialOwner, address _relayer, address _tokenManager) initializer public {
        __TokenBridgeManager_init(initialOwner, _relayer, _tokenManager);
        __Pausable_init();
        __UUPSUpgradeable_init();
    }

    function setTokenFactory(address _tokenFactory) external restricted {
        if (_tokenFactory == address(0)) revert InvalidFactory();
        tokenFactory = TokenFactory(_tokenFactory);
    }

    function setVerifier(address _verifier) external restricted {
        if (_verifier == address(0)) revert InvalidVerifier();
        verifier = IProofVerifier(_verifier);
    }

    function configureToken(
        address token,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 dailyLimit,
        uint256[] calldata targetChainIds,
        address[] calldata targetTokens
    ) external onlyTokenManager {
        if (targetChainIds.length != targetTokens.length) revert InvalidToken();
        
        uint8 decimals = IERC20Metadata(token).decimals();
        
        // Check if token supports mint and burn operations
        try IMintableBurnableToken(token).mint(address(this), 0) {
            // Token supports mint
        } catch {
            revert NotMintableBurnable();
        }
        
        try IMintableBurnableToken(token).burn(address(this), 0) {
            // Token supports burn
        } catch {
            revert NotMintableBurnable();
        }
        
        supportedTokens[token] = TokenConfig({
            isSupported: true,
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

    function removeToken(address token) external onlyTokenManager {
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
    ) external onlyRelayer whenNotPaused {
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
            timestamp: block.timestamp,
            sourceChainId: block.chainid
        });

        bytes32 operationHash = _hashOperation(operation);
        if (operationProofs[operationHash].length > 0) revert TransactionAlreadyProcessed();
        
        // Burn the tokens
        IMintableBurnableToken(token).burn(msg.sender, amount);
        
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

    function relayOperation(
        BridgeOperation calldata operation,
        bytes calldata proofBytes
    ) external onlyValidator {
        bytes32 operationHash = _hashOperation(operation);
        
        // Verify this is a valid target chain operation
        if (operation.targetChainId != block.chainid) revert InvalidOperation();
        
        // Store the proof for this operation
        operationProofs[operationHash] = proofBytes;
        
        emit OperationRelayed(
            operationHash,
            operation.sourceChainId,
            operation.targetChainId
        );
    }

    function mintTokens(
        address token,
        address to,
        uint256 amount,
        BridgeOperation calldata operation
    ) external onlyValidator whenNotPaused {
        TokenConfig memory config = supportedTokens[token];
        if (!config.isSupported) revert InvalidToken();
        
        // Verify the operation hash
        bytes32 operationHash = _hashOperation(operation);
        bytes memory proofBytes = operationProofs[operationHash];
        if (proofBytes.length == 0) revert TransactionAlreadyProcessed();
        
        // Prepare public values for verification
        bytes memory publicValues = abi.encode(
            operation.token,
            operation.sender,
            operation.receiver,
            operation.amount,
            operation.targetChainId,
            operation.nonce,
            operation.timestamp,
            operation.sourceChainId
        );
        
        // Verify the proof
        verifier.verifyProof(publicValues, proofBytes);
        
        _validateAmount(token, amount);
        _updateDailyLimit(token, amount);
        
        // Clear the proof to prevent replay
        delete operationProofs[operationHash];
        
        IMintableBurnableToken(token).mint(to, amount);
        
        emit TokenMinted(
            token,
            to,
            amount,
            operation.sourceChainId,
            operationHash
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
                operation.timestamp,
                operation.sourceChainId
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

    function checkTokenExists(
        address token,
        uint256 targetChainId
    ) external view returns (bool) {
        return tokenPairs[token][targetChainId] != address(0);
    }

    function computeTokenAddress(
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        bytes32 salt
    ) external view returns (address) {
        return tokenFactory.computeTokenAddress(name, symbol, decimals, salt);
    }

    function deployBridgeToken(
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        uint256 targetChainId,
        bytes32 salt
    ) external restricted returns (address) {
        if (address(tokenFactory) == address(0)) revert InvalidFactory();
        if (salt == bytes32(0)) revert InvalidSalt();

        // Check if token already exists for this chain
        if (tokenPairs[address(0)][targetChainId] != address(0)) {
            revert TokenAlreadyExists();
        }

        // Deploy new token using factory
        address newToken = tokenFactory.deployToken(name, symbol, decimals, salt);
        
        // Grant mint and burn roles to this contract
        BridgeToken(newToken).grantRole(BridgeToken(newToken).MINTER_ROLE(), address(this));
        BridgeToken(newToken).grantRole(BridgeToken(newToken).BURNER_ROLE(), address(this));

        // Configure the token in the bridge
        uint256[] memory targetChainIds = new uint256[](1);
        address[] memory targetTokens = new address[](1);
        targetChainIds[0] = targetChainId;
        targetTokens[0] = newToken;

        this.configureToken(
            newToken,
            0, // minAmount
            type(uint256).max, // maxAmount
            type(uint256).max, // dailyLimit
            targetChainIds,
            targetTokens
        );

        return newToken;
    }
} 