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
forge script --chain <chian_name> --rpc-url <rpc_url> --private-key ${PRIVATE_KEY} --broadcast <deploy_script.s.sol>:<contract_script_name>
```

### Contracts Verification
```shell
forge verify-contract <contract_address> \
  <path_to_contract.sol>:<contract_name> \
  --chain <chian_name> \
  --verifier etherscan \
  --verifier-api-key ${ethersccan_api_key} \
  --constructor-args "<encoded_args_bytes>"
```
####  Verification for ERC1967 Proxy

1. calldata for initilizer
```shell
$ cast calldata "function initialize(address,address,address)" "<arg1>" "<arg2>" "<arg3>" 
```
2. Use cast for init code
```shell
$ cast abi-encode "constructor(address, bytes)" "<impl_address>" "<the above encoded calldata>"
```

3. verify proxy contract with above constructor args
```shell
$ forge verify-contract <contract_address> \
  ./dependencies/@openzeppelin-contracts-5.1.0/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "the encoded calldata from above"
```


#### Verify handler deployed with create2
```shell
cast abi-encode "constructor(address, address, address)" "0x3fcbaf4822e7c7364e43aec8253dfc888b9235bb" "0x3fcbaf4822e7c7364e43aec8253dfc888b9235bb" "0xa88c1c777a056510331325dfad71140320dd8865"

forge verify-contract <contract_address> \
  ./contracts/handlers/ERC20Handler.sol:ERC20Handler \
 --chain ${DEPLOY_CONFIG} \
  --verifier etherscan \
  --verifier-api-key ${ETHERSCAN_MAINNET_KEY} \
  --constructor-args "<encoded call data>"
```
