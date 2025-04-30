# Token Bridge Usage Guide: Existing ERC-20 to New Token

## Overview
This guide explains how to use the TokenBridge to bridge an existing ERC-20 token to a new mintable token on the destination chain.

## Setup Process

### 1. Deploy Bridge Contracts
```solidity
// On Source Chain (Existing Token)
TokenBridge sourceBridge = new TokenBridge();
sourceBridge.initialize(owner);

// On Destination Chain (New Token)
TokenBridge destBridge = new TokenBridge();
destBridge.initialize(owner);
```

### 2. Deploy BridgeToken on Destination Chain
```solidity
// On Destination Chain
BridgeToken newToken = new BridgeToken();
newToken.initialize(
    "New Token",  // name
    "NTK",        // symbol
    owner,        // admin
    destBridge    // bridge address
);
```

### 3. Configure Token Pairs
```solidity
// On Source Chain
sourceBridge.configureToken(
    existingToken,  // address of existing ERC-20
    false,          // isBridgeToken = false (existing token)
    minAmount,      // minimum transfer amount
    maxAmount,      // maximum transfer amount
    dailyLimit,     // daily transfer limit
    [destChainId],  // target chain IDs
    [newToken]      // corresponding target tokens
);

// On Destination Chain
destBridge.configureToken(
    newToken,       // address of new BridgeToken
    true,           // isBridgeToken = true (mintable token)
    minAmount,      // minimum transfer amount
    maxAmount,      // maximum transfer amount
    dailyLimit,     // daily transfer limit
    [sourceChainId],// source chain IDs
    [existingToken] // corresponding source tokens
);
```

## Usage Flow

### 1. User Locks Tokens on Source Chain
```solidity
// User approves bridge to spend tokens
existingToken.approve(sourceBridge, amount);

// User locks tokens
sourceBridge.lockTokens(
    existingToken,  // token to lock
    receiver,       // destination address
    amount,         // amount to transfer
    destChainId     // destination chain ID
);
```

### 2. Validator Monitors and Mints on Destination Chain
```solidity
// Validator calls mintTokens on destination chain
destBridge.mintTokens(
    newToken,           // token to mint
    receiver,           // destination address
    convertedAmount,    // amount after decimal conversion
    sourceChainId,      // source chain ID
    sourceTxHash        // source transaction hash
);
```

## Important Notes

1. **Decimal Handling**
   - The bridge automatically handles decimal differences
   - Use `calculateTargetAmount` to preview converted amounts:
   ```solidity
   uint256 targetAmount = bridge.calculateTargetAmount(
       existingToken,
       sourceAmount,
       destChainId
   );
   ```

2. **Security Considerations**
   - Only the validator can mint tokens
   - Each operation is tracked by hash to prevent replay attacks
   - Daily limits prevent excessive transfers
   - Bridge can be paused in emergencies

3. **Role Management**
   - Bridge contract must have `BRIDGE_ROLE` on the destination token
   - Admin can grant/revoke roles as needed
   - Validator address must be set before operations

4. **Error Handling**
   - Check for common errors:
     - `InvalidToken`: Token not configured
     - `InvalidAmount`: Amount outside limits
     - `DailyLimitExceeded`: Daily transfer limit reached
     - `TransactionAlreadyProcessed`: Duplicate operation
     - `NotBridgeToken`: Attempt to mint non-mintable token

## Example Transaction Flow

1. User has 1000 USDC (6 decimals) on Ethereum
2. Wants to bridge to a new token (18 decimals) on Polygon
3. Bridge calculates equivalent amount:
   ```solidity
   // 1000 USDC (6 decimals) = 1000 * 10^12 new tokens (18 decimals)
   uint256 targetAmount = 1000 * 10**12;
   ```
4. User locks USDC on Ethereum
5. Validator mints equivalent amount of new tokens on Polygon 