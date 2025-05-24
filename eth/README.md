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
forge script --chain ${DEPLOY_CONFIG} --rpc-url ${RPC_HOLESKY} --private-key ${PRIVATE_KEY} --broadcast script/DeployMockVerifier.s.sol:DeployMockVerifier
forge script --chain ${DEPLOY_CONFIG} --rpc-url ${RPC_HOLESKY} --private-key ${PRIVATE_KEY} --broadcast script/DeployCreate2.s.sol:DeployCreate2Deployer
forge script --chain ${DEPLOY_CONFIG} --rpc-url ${RPC_HOLESKY} --private-key ${PRIVATE_KEY} --broadcast ./script/BridgeDeploy.s.sol:BridgeDeployScript
forge script --chain ${DEPLOY_CONFIG} --rpc-url ${RPC_HOLESKY} --private-key ${PRIVATE_KEY} --broadcast script/HandlerDeploy.s.sol:HandlerDeployScript
forge script --chain ${DEPLOY_CONFIG} --rpc-url ${RPC_HOLESKY} --private-key ${PRIVATE_KEY} --broadcast script/DeployTestToken.s.sol:DeployTestToken
```

### Contracts Verification
```shell
forge verify-contract 0x27ba4134af53fed20350e2cb644df4e0201ee89b \
  ./script/utils/Create2Deployer.sol:Create2Deployer \
  --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "0x"


forge verify-contract 0xf6f704b2684804857774258aa4715c6328287475 \
  ./contracts/mocks/MockVerifier.sol:MockVerifier \
  --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "0x"

forge verify-contract 0x8db7f4b7f08fdca96e934fcda2792226da8c6a5c \
  ./contracts/Bridge.sol:Bridge \
  --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "0x"

 # verify ERC1967PROXY
 # 1. calldata for bridge initilizer
$ cast calldata "function initialize(address,address,address)" "0x3fcbaf4822e7c7364e43aec8253dfc888b9235bb" "0x3fcbaf4822e7c7364e43aec8253dfc888b9235bb" "0xf6f704b2684804857774258aa4715c6328287475" 

# 2. Use cast for init code
$ cast abi-encode "constructor(address, bytes)" "<impl_address>" "<the above encoded calldata>"
 
# 3. verify proxy contract with above constructor args
$ forge verify-contract \0xf618e1c29064699f858ff239cb369d74b7d5bbcd \
  ./dependencies/@openzeppelin-contracts-5.1.0/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "the encoded calldata from above"

# verify handler deployed with create2
cast abi-encode "constructor(address, address, address)" "0x3fcbaf4822e7c7364e43aec8253dfc888b9235bb" "0x3fcbaf4822e7c7364e43aec8253dfc888b9235bb" "0xa88c1c777a056510331325dfad71140320dd8865"

forge verify-contract 0x69e148ba5ed27f3571cfadb4fc34471a7e019ff6 \
  ./contracts/handlers/ERC20Handler.sol:ERC20Handler \
 --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "0x0000000000000000000000003fcbaf4822e7c7364e43aec8253dfc888b9235bb0000000000000000000000003fcbaf4822e7c7364e43aec8253dfc888b9235bb000000000000000000000000a88c1c777a056510331325dfad71140320dd8865"

  # verify test token
  forge verify-contract 0x5fD73B896C636E71DBa00d36009C583D703E625C \
  contracts/TestToken.sol:TestToken \
  --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "0x000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000d3c21bcecceda1000000000000000000000000000000000000000000000000000000000000000000000a5465737420546f6b656e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000045445535400000000000000000000000000000000000000000000000000000000" 
```
