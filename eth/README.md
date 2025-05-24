# The3Cloud - Token Bridge

### Build

```shell
$ forge build
```

### Test

```shell
# run all tests
$ forge test
# run a single file
$ forge test --match-path <test_file.t.sol> -vv
$ forge test --match-path test/Bridge.t.sol -vv
$ forge test --match-path test/ERC20Handler.t.sol -vv
# run a single test 
$ forge test --match-test <test_function_name> --vv
$ forge test --match-test test_SendMessage -vv
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```


### Deployment

```shell
cd eth
cp .env-example .env
# edit .env section
source .env
cast send --value 10ether --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 ${PUBLIC_ADDRESS}
forge script --chain ${DEPLOY_CONFIG} --rpc-url ${RPC_SEPOLIA} --private-key ${PRIVATE_KEY} --broadcast script/DeployMockVerifier.s.sol:DeployMockVerifier
forge script --chain ${DEPLOY_CONFIG} --rpc-url ${RPC_SEPOLIA} --private-key ${PRIVATE_KEY} --broadcast script/DeployCreate2.s.sol:DeployCreate2Deployer
forge script --chain ${DEPLOY_CONFIG} --rpc-url ${RPC_SEPOLIA} --private-key ${PRIVATE_KEY} --broadcast ./script/BridgeDeploy.s.sol:BridgeDeployScript
forge script --chain ${DEPLOY_CONFIG} --rpc-url ${RPC_SEPOLIA} --private-key ${PRIVATE_KEY} --broadcast ./script/BridgeDeploy.s.sol:BridgeDeployScript
```
