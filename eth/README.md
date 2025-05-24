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
forge script --chain ${DEPLOY_CONFIG} --rpc-url ${RPC_SEPOLIA} --private-key ${PRIVATE_KEY} --broadcast script/HandlerDeploy.s.sol:HandlerDeployScript
forge script --chain ${DEPLOY_CONFIG} --rpc-url ${RPC_SEPOLIA} --private-key ${PRIVATE_KEY} --broadcast script/DeployTestToken.s.sol:DeployTestToken
```

### Contracts Verification
```shell
forge verify-contract 0x57fd38947bfea96a0ef15f2f79d7f37f66d38a13 \
  ./script/utils/Create2Deployer.sol:Create2Deployer \
  --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "0x"


forge verify-contract 0xa2d9ff44240d8d8c66827216fe9086bbbb6512d0 \
  ./contracts/mocks/MockVerifier.sol:MockVerifier \
  --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "0x"

forge verify-contract 0x5da09dcc4b4f2c723738788f92fff2455f080b6d \
  ./contracts/Bridge.sol:Bridge \
  --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "0x"

 # verify ERC1967PROXY
 # 1. run ./script/BridgeInitCode.s.sol for initilizer selector and args
 $ forge script ./script/BridgeInitCode.s.sol
 >> == Logs ==
  0xc0c53b8b0000000000000000000000003fcbaf4822e7c7364e43aec8253dfc888b9235bb0000000000000000000000003fcbaf4822e7c7364e43aec8253dfc888b9235bb000000000000000000000000b3bb470d42b72307181a845af2fc2e70d00db801
# 2. Use cast for init code
$ cast abi-encode "constructor(address, bytes)" "<impl_address>" "<the above initilizer_selector+args>"
>> 0x0000000000000000000000005da09dcc4b4f2c723738788f92fff2455f080b6d00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000064c0c53b8b0000000000000000000000003fcbaf4822e7c7364e43aec8253dfc888b9235bb0000000000000000000000003fcbaf4822e7c7364e43aec8253dfc888b9235bb000000000000000000000000b3bb470d42b72307181a845af2fc2e70d00db80100000000000000000000000000000000000000000000000000000000
# 3. verify proxy contract with above constructor args
$ forge verify-contract 0x8d8a33724b8ce81547270efe2282cd0a4fd6280d \
  ./dependencies/@openzeppelin-contracts-5.1.0/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "0x0000000000000000000000005da09dcc4b4f2c723738788f92fff2455f080b6d00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000064c0c53b8b0000000000000000000000003fcbaf4822e7c7364e43aec8253dfc888b9235bb0000000000000000000000003fcbaf4822e7c7364e43aec8253dfc888b9235bb000000000000000000000000b3bb470d42b72307181a845af2fc2e70d00db80100000000000000000000000000000000000000000000000000000000"

# verify handler deployed with create2
cast abi-encode "constructor(address, address, address)" "0x3fcbaf4822e7c7364e43aec8253dfc888b9235bb" "0x3fcbaf4822e7c7364e43aec8253dfc888b9235bb" "0x8d8a33724b8ce81547270efe2282cd0a4fd6280d"
forge verify-contract 0xea65ca38968698eda772459ae675edb40001b769 \
  ./contracts/handlers/ERC20Handler.sol:ERC20Handler \
 --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "0x0000000000000000000000003fcbaf4822e7c7364e43aec8253dfc888b9235bb0000000000000000000000003fcbaf4822e7c7364e43aec8253dfc888b9235bb0000000000000000000000008d8a33724b8ce81547270efe2282cd0a4fd6280d"

  # verify test token
  forge verify-contract 0xeebB01feC75391FB082FFC7555dF5Fd3AB75fA8f \
  contracts/TestToken.sol:TestToken \
  --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "0x000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000d3c21bcecceda1000000000000000000000000000000000000000000000000000000000000000000000a5465737420546f6b656e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000045445535400000000000000000000000000000000000000000000000000000000" 
```
