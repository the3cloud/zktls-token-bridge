## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

### Deployment

```shell
cd eth
source .env
cast send --value 10ether --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 ${PUBLIC_ADDRESS}

forge script --chain 31337 --rpc-url http://127.0.0.1:8545 --private-key ${PRIVATE_KEY} --broadcast script/DeployMockVerifier.s.sol:DeployMockVerifier

forge script --chain 31337 --rpc-url http://127.0.0.1:8545 --private-key ${PRIVATE_KEY} --broadcast script/DeployCreate2.s.sol:DeployCreate2Deployer

forge script --chain 31337 --rpc-url http://127.0.0.1:8545 --private-key ${PRIVATE_KEY} --broadcast ./script/BridgeDeploy.s.sol:BridgeDeployScript

forge script --chain 31337 --rpc-url http://127.0.0.1:8545 --private-key ${PRIVATE_KEY} --broadcast ./script/BridgeDeploy.s.sol:BridgeDeployScript
```
