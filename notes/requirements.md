# Requirements

## ETH TokenBridge

1. Generic ERC20 Support:
* Works with any existing ERC20 token
* Configurable token pairs between chains

2. Decimal Handling:
* Automatic decimal adjustment between chains
* calculateTargetAmount function to preview converted amounts

3. Enhanced Security:
* Daily limits with automatic reset
* Minimum and maximum amount constraints
* Custom errors for better gas efficiency
* Nonce-based operation tracking

4. Configuration Features:
* Token pair mapping between chains
* Configurable limits per token
* Support for multiple target chains per token

5. Operation Management:
* Structured operation data
* Hash-based operation tracking
* Comprehensive event logging

### To use the bridge 

1. Deploy the bridge contract on each chain using the UUPS proxy pattern
2. Configure token pairs between chains using `configureToken`
3. Set up the validator address
4. Users can then:
    * Call lockTokens on the source chain
    * Validator monitors events and calls releaseTokens on the target chain
    * Use calculateTargetAmount to preview converted amounts

> The bridge handles decimal differences automatically. For example, if you're bridging from a token with 18 decimals to one with 6 decimals, the amount will be automatically adjusted.




