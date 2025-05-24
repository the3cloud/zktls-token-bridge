// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../contracts/Bridge.sol";
import "../contracts/interfaces/IHandler.sol";
import "../contracts/mocks/MockVerifier.sol";

import {UpgradeableDeployer} from "../script/utils/UpgradeableDeployer.sol";
import {Create2Deployer} from "../script/utils/Create2Deployer.sol";

contract MockHandler is IHandler {
    bool public success = true;

    function setSuccess(bool _success) external {
        success = _success;
    }

    function handleDelivery(bytes calldata) external view override returns (bool) {
        return success;
    }

    function handleTransfer(bytes calldata) external view override returns (bytes memory) {
        return abi.encode(success);
    }
}

contract BridgeTest is Test, UpgradeableDeployer {
    Bridge public testBridge;
    MockHandler public handler;
    MockVerifier public verifier;
    address public tokenManager;
    address public owner;
    address public test_user;

    event MessageSent(
        uint256 fromChainId,
        address indexed fromHandler,
        uint256 toChainId,
        address indexed toHandler,
        uint256 nonce,
        bytes message
    );

    event MessageDelivered(
        uint256 fromChainId,
        address indexed fromHandler,
        uint256 toChainId,
        address indexed toHandler,
        uint256 nonce,
        bytes message
    );

    function setUp() public {
        test_user = makeAddr("test_user");
        owner = makeAddr("bridge_owner");
        tokenManager = makeAddr("token_manager");
        vm.deal(owner, 100 ether);

        Create2Deployer deployer = new Create2Deployer();
        handler = new MockHandler();
        verifier = new MockVerifier();

        // Deploy the implementation and proxy
        (address proxy,) = deployUUPS(
            deployer,
            "Bridge",
            type(Bridge).creationCode,
            abi.encodeCall(Bridge.initialize, (owner, tokenManager, address(verifier)))
        );

        // Cast the proxy address to Bridge interface
        testBridge = Bridge(proxy);
    }

    function test_SendMessage() public {
        vm.prank(tokenManager);
        testBridge.registerHandler(address(handler));

        uint256 destChainId = 2;
        address destHandler = address(handler);
        bytes memory message = "test message";

        vm.prank(address(handler));
        vm.expectEmit(true, true, false, true);
        emit MessageSent(block.chainid, address(handler), destChainId, destHandler, 1, message);
        uint256 nonce = testBridge.sendMessage(destChainId, destHandler, message);
        assertEq(nonce, 1);
    }

    function test_RevertWhen_SendMessageUnregisteredHandler() public {
        uint256 destChainId = 2;
        address destHandler = address(handler);
        bytes memory message = "test message";

        vm.prank(address(handler));
        vm.expectRevert("Handler not registered");
        testBridge.sendMessage(destChainId, destHandler, message);
    }

    function test_RevertWhen_SendMessageZeroAddressHandler() public {
        vm.prank(tokenManager);
        testBridge.registerHandler(address(handler));

        vm.prank(address(handler));
        vm.expectRevert("Invalid destination handler");
        testBridge.sendMessage(2, address(0), "test message");
    }

    function test_DeliverMessage() public {
        vm.prank(tokenManager);
        testBridge.registerHandler(address(handler));

        uint256 srcChainId = 1;
        address srcHandler = address(handler);
        address destHandler = address(handler);
        uint256 messageNonce = 1;
        bytes memory message = "test message";
        bytes memory proofBytes = "";

        vm.prank(address(handler));
        vm.expectEmit(true, true, false, true);
        emit MessageDelivered(srcChainId, srcHandler, block.chainid, destHandler, messageNonce, message);
        testBridge.deliverMessage(srcChainId, srcHandler, destHandler, messageNonce, message, proofBytes);

        assertTrue(testBridge.completedMessages(srcChainId, messageNonce));
    }

    function test_RevertWhen_DeliverMessageAlreadyCompleted() public {
        vm.prank(tokenManager);
        testBridge.registerHandler(address(handler));

        uint256 srcChainId = 1;
        address srcHandler = address(handler);
        address destHandler = address(handler);
        uint256 messageNonce = 1;
        bytes memory message = "test message";
        bytes memory proofBytes = "";

        vm.prank(address(handler));
        testBridge.deliverMessage(srcChainId, srcHandler, destHandler, messageNonce, message, proofBytes);

        vm.prank(address(handler));
        vm.expectRevert("Message already delivered");
        testBridge.deliverMessage(srcChainId, srcHandler, destHandler, messageNonce, message, proofBytes);
    }

    function test_RevertWhen_DeliverMessageUnregisteredHandler() public {
        uint256 srcChainId = 1;
        address srcHandler = address(handler);
        address destHandler = address(handler);
        uint256 messageNonce = 1;
        bytes memory message = "test message";
        bytes memory proofBytes = "";

        vm.prank(address(handler));
        vm.expectRevert("Handler not registered");
        testBridge.deliverMessage(srcChainId, srcHandler, destHandler, messageNonce, message, proofBytes);
    }

    function test_RevertWhen_DeliverMessageFailedVerification() public {
        vm.prank(tokenManager);
        testBridge.registerHandler(address(handler));

        uint256 srcChainId = 1;
        address srcHandler = address(handler);
        address destHandler = address(handler);
        uint256 messageNonce = 1;
        bytes memory message = "test message";
        bytes memory proofBytes = "invalid proof";

        vm.prank(address(handler));
        vm.expectRevert("InvalidProof()");
        testBridge.deliverMessage(srcChainId, srcHandler, destHandler, messageNonce, message, proofBytes);
    }

    function test_RevertWhen_DeliverMessageFailedHandler() public {
        vm.prank(tokenManager);
        testBridge.registerHandler(address(handler));
        handler.setSuccess(false);

        uint256 srcChainId = 1;
        address srcHandler = address(handler);
        address destHandler = address(handler);
        uint256 messageNonce = 1;
        bytes memory message = "test message";
        bytes memory proofBytes = "";

        vm.prank(address(handler));
        vm.expectRevert("Handler delivery failed");
        testBridge.deliverMessage(srcChainId, srcHandler, destHandler, messageNonce, message, proofBytes);
    }
}
