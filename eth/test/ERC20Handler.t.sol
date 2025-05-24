// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/handlers/ERC20Handler.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/Bridge.sol";
import {UpgradeableDeployer} from "../script/utils/UpgradeableDeployer.sol";
import {Create2Deployer} from "../script/utils/Create2Deployer.sol";
import {MockVerifier} from "../contracts/mocks/MockVerifier.sol";

contract TestERC20 is ERC20 {
    constructor() ERC20("Test Token", "TTK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract ERC20HandlerTest is Test, UpgradeableDeployer {
    ERC20Handler public srcHandler;
    ERC20Handler public destHandler;
    TestERC20 public token;
    Bridge public testBridge;
    address public admin;
    address public tokenManager;
    address public user;
    uint256 public constant SOURCE_CHAIN_ID = 1;
    uint256 public constant DEST_CHAIN_ID = 2;
    uint256 public constant INITIAL_LIMIT = 1000 * 10 ** 18;

    function _configureBridge(Create2Deployer deployer_, address admin_, address tokenManager_, address verifier_)
        internal
    {}

    event TokenSupportAdded(
        address indexed srcToken,
        uint256 indexed destChainId,
        address destToken,
        address destHandler,
        uint8 decimals,
        uint256 limit
    );

    event TokenLocked(address indexed token, address indexed sender, uint256 srcAmount, uint256 destAmount);

    event TokenUnlocked(address indexed token, address indexed receiver, uint256 amount);

    event TokenLimitUpdated(address indexed token, uint256 indexed chainId, uint256 maxTransferLimit);

    function _setUpTokenSupport() internal {
        // Setup token support
        vm.startPrank(tokenManager);
        srcHandler.addTokenSupport(
            address(token),
            address(token), // for test purpose, using the same token for src and dest chain
            DEST_CHAIN_ID,
            address(destHandler),
            18, // decimals
            INITIAL_LIMIT
        );
        destHandler.addTokenSupport(
            address(token),
            address(token), // for test purpose, using the same token for src and dest chain
            SOURCE_CHAIN_ID,
            address(srcHandler),
            18, // decimals
            INITIAL_LIMIT
        );
        vm.stopPrank();
    }

    function setUp() public {
        admin = makeAddr("admin");
        tokenManager = makeAddr("tokenManager");
        user = makeAddr("user");

        vm.startPrank(admin);
        Create2Deployer deployer = new Create2Deployer();
        MockVerifier verifier = new MockVerifier();
        // deploy bridge
        (address proxy,) = deployUUPS(
            deployer,
            "Bridge",
            type(Bridge).creationCode,
            abi.encodeCall(Bridge.initialize, (admin, admin, address(verifier)))
        );
        testBridge = Bridge(proxy);
        // deploy handler
        address srcHandlerAddress = deployer.deploy(
            keccak256(abi.encodePacked("SrcERC20Handler")),
            type(ERC20Handler).creationCode,
            abi.encode(admin, tokenManager, address(testBridge))
        );
        srcHandler = ERC20Handler(srcHandlerAddress);
        address destHandlerAddress = deployer.deploy(
            keccak256(abi.encodePacked("DestERC20Handler")),
            type(ERC20Handler).creationCode,
            abi.encode(admin, tokenManager, address(testBridge))
        );
        destHandler = ERC20Handler(destHandlerAddress);
        testBridge.registerHandler(address(srcHandler));
        testBridge.registerHandler(address(destHandler));
        token = new TestERC20();
        //Transfer some tokens to user
        token.transfer(user, 1000 * 10 ** 18);
        vm.stopPrank();
        // Transfer some tokens to user
        vm.startPrank(admin);
        token.transfer(user, 1000 * 10 ** 18);
        token.transfer(address(destHandler), 10000 * 10 ** 18);
        vm.stopPrank();
    }

    function test_AddTokenSupport() public {
        vm.expectEmit(true, true, true, true);
        emit TokenSupportAdded(address(token), DEST_CHAIN_ID, address(token), address(destHandler), 18, INITIAL_LIMIT);
        emit TokenSupportAdded(address(token), SOURCE_CHAIN_ID, address(token), address(srcHandler), 18, INITIAL_LIMIT);

        _setUpTokenSupport();

        assertEq(destHandler.tokenDecimals(address(token), SOURCE_CHAIN_ID), 18);
        assertEq(destHandler.destHandlers(address(token), SOURCE_CHAIN_ID), address(srcHandler));
        assertEq(destHandler.destTokens(address(token), SOURCE_CHAIN_ID), address(token));
        assertEq(destHandler.maxTransferLimit(address(token), SOURCE_CHAIN_ID), INITIAL_LIMIT);
        assertFalse(destHandler.tokenPaused(address(token)));
    }

    function test_HandleTransfer() public {
        uint256 amount = 100 * 10 ** 18;
        _setUpTokenSupport();

        vm.startPrank(user);
        token.approve(address(srcHandler), amount);

        bytes memory data = abi.encode(address(token), DEST_CHAIN_ID, amount, user);

        srcHandler.handleTransfer(data);

        assertEq(token.balanceOf(address(srcHandler)), amount);
    }

    function test_HandleTransferExceedsLimit() public {
        uint256 amount = INITIAL_LIMIT + 1;
        _setUpTokenSupport();
        vm.startPrank(user);
        token.approve(address(srcHandler), amount);

        bytes memory data = abi.encode(address(token), DEST_CHAIN_ID, amount, user);

        vm.expectRevert("Exceeds transfer limit");
        srcHandler.handleTransfer(data);
    }

    function test_HandleTransferPausedToken() public {
        vm.startPrank(tokenManager);
        srcHandler.setTokenPaused(address(token), true);
        vm.stopPrank();

        uint256 amount = 100 * 10 ** 18;
        vm.startPrank(user);
        token.approve(address(srcHandler), amount);

        bytes memory data = abi.encode(address(token), DEST_CHAIN_ID, amount, user);

        vm.expectRevert("Token is paused");
        srcHandler.handleTransfer(data);
    }

    function test_HandleDelivery() public {
        uint256 amount = 100 * 10 ** 18;
        uint256 initialBalance = token.balanceOf(user);
        _setUpTokenSupport();
        // First transfer tokens to handler
        vm.startPrank(user);
        token.approve(address(srcHandler), amount);
        bytes memory transferData = abi.encode(address(token), DEST_CHAIN_ID, amount, user);
        bytes memory messageBytes = srcHandler.handleTransfer(transferData);

        vm.stopPrank();

        // Now test delivery
        bytes memory expectedDeliveryData = abi.encode(address(token), amount, user);
        assertEq(keccak256(messageBytes), keccak256(expectedDeliveryData));

        vm.expectEmit(true, true, false, true);
        emit TokenUnlocked(address(token), user, amount);

        testBridge.deliverMessage(
            SOURCE_CHAIN_ID,
            address(srcHandler),
            address(destHandler),
            1,
            messageBytes,
            "" // proofBytes
        );

        assertEq(token.balanceOf(user), initialBalance); // Back to initial balance
    }

    function test_GetConvertibleAmount() public {
        uint256 amount = 100 * 10 ** 18;
        _setUpTokenSupport();

        (uint256 destAmount, uint256 usedSrcAmount, uint256 dust) =
            srcHandler.getConvertibleAmount(address(token), DEST_CHAIN_ID, amount);

        assertEq(destAmount, amount);
        assertEq(usedSrcAmount, amount);
        assertEq(dust, 0);
    }

    function test_SetTransferLimit() public {
        uint256 newLimit = 2000 * 10 ** 18;
        vm.startPrank(tokenManager);

        vm.expectEmit(true, true, false, true);
        emit TokenLimitUpdated(address(token), DEST_CHAIN_ID, newLimit);

        srcHandler.setTransferLimit(address(token), DEST_CHAIN_ID, newLimit);

        assertEq(srcHandler.maxTransferLimit(address(token), DEST_CHAIN_ID), newLimit);
    }

    function test_RemoveTokenSupport() public {
        vm.startPrank(tokenManager);

        srcHandler.removeTokenSupport(address(token), DEST_CHAIN_ID);

        assertEq(srcHandler.tokenDecimals(address(token), DEST_CHAIN_ID), 0);
        assertEq(srcHandler.destHandlers(address(token), DEST_CHAIN_ID), address(0));
        assertEq(srcHandler.maxTransferLimit(address(token), DEST_CHAIN_ID), 0);
    }
}
