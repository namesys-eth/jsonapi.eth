// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TickerManager.sol";
import "../src/Utils.sol";
import {iERC20, iERC721} from "../src/interfaces/IERC.sol";

contract TickerManagerTest is Test {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant ENS_NFT = 0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85;
    address constant BAYC = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant PUNKS = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    address constant VITALIK = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    event TickerUpdated(bytes32 indexed node, address indexed addr, uint256 erc);

    TickerManager public tickerManager;
    address owner = address(0);
    address nonOwner = address(2);
    address user = address(3);

    function setUp() public {
        vm.startPrank(owner);
        tickerManager = new TickerManager();
        vm.stopPrank();
    }

    function getNode(string memory ticker) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(tickerManager.JSONAPIRoot(), keccak256(bytes(ticker))));
    }

    function getHash(string memory ticker) internal pure returns (bytes32) {
        return keccak256(bytes(ticker));
    }

    function test_SetTicker() public {
        vm.startPrank(owner);

        // Test ERC20
        bytes32 hash = getHash("usdc");
        bytes32 node = getNode("usdc");
        vm.expectEmit(true, true, true, true);
        emit TickerUpdated(node, USDC, 20);
        tickerManager.setTicker(USDC, hash);

        address addr = tickerManager.Tickers(node);
        assertEq(addr, USDC);

        // Test ERC721
        hash = getHash("bayc");
        node = getNode("bayc");
        vm.expectEmit(true, true, true, true);
        emit TickerUpdated(node, BAYC, 721);
        tickerManager.setTicker(BAYC, hash);

        addr = tickerManager.Tickers(node);
        assertEq(addr, BAYC);

        vm.stopPrank();
    }

    function test_SetTicker_RevertIfNotOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(ERC173.OnlyOwner.selector);
        tickerManager.setTicker(USDC, getHash("usdc"));
        vm.stopPrank();
    }

    function test_SetTicker_RevertIfInvalidContract() public {
        vm.startPrank(owner);
        vm.expectRevert(TickerManager.NotTokenContract.selector);
        tickerManager.setTicker(address(this), getHash("TEST"));

        vm.expectRevert(TickerManager.NotTokenContract.selector);
        tickerManager.setTicker(address(user), getHash("TEST"));
        vm.stopPrank();
    }

    function test_RemoveTicker() public {
        vm.startPrank(owner);
        bytes32 hash = getHash("usdc");
        bytes32 node = getNode("usdc");
        tickerManager.setTicker(USDC, hash);

        vm.expectEmit(true, true, true, true);
        emit TickerUpdated(node, address(0), 0);
        tickerManager.removeTicker(node);

        address addr = tickerManager.Tickers(node);
        assertEq(addr, address(0));
        vm.stopPrank();
    }

    function test_RemoveTicker_RevertIfNotOwner() public {
        vm.startPrank(owner);
        bytes32 hash = getHash("usdc");
        bytes32 node = getNode("usdc");
        tickerManager.setTicker(USDC, hash);
        vm.stopPrank();

        vm.startPrank(nonOwner);
        vm.expectRevert(ERC173.OnlyOwner.selector);
        tickerManager.removeTicker(node);
        vm.stopPrank();
    }

    function test_RemoveTicker_RevertIfNotExists() public {
        vm.startPrank(owner);
        bytes32 node = getNode("usdc");
        vm.expectRevert(abi.encodeWithSelector(TickerManager.TickerNotFound.selector, node));
        tickerManager.removeTicker(node);
        vm.stopPrank();
    }

    function test_ETHDefaults() public view {
        bytes32 ethNode = getNode("eth");
        address addr = tickerManager.Tickers(ethNode);
        assertEq(addr, address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    }

    function test_SetTicker_RevertIfDuplicate() public {
        vm.startPrank(owner);
        bytes32 hash = getHash("usdc");
        tickerManager.setTicker(USDC, hash);

        vm.expectRevert(abi.encodeWithSelector(TickerManager.DuplicateTicker.selector, getNode("usdc")));
        tickerManager.setTicker(USDC, hash);
        vm.stopPrank();
    }

    function test_SetTicker_EmptyCode() public {
        vm.startPrank(owner);
        address emptyAddr = address(0x1234);
        vm.expectRevert(TickerManager.NotTokenContract.selector);
        tickerManager.setTicker(emptyAddr, getHash("TEST"));
        vm.stopPrank();
    }

    function test_SetTickerBatch() public {
        vm.startPrank(owner);

        address[] memory addrs = new address[](2);
        bytes32[] memory hashes = new bytes32[](2);

        // Setup test data
        addrs[0] = USDC;
        addrs[1] = BAYC;
        hashes[0] = getHash("usdc");
        hashes[1] = getHash("bayc");

        // Test batch setting
        tickerManager.setTickerBatch(addrs, hashes);

        // Verify each ticker
        for (uint256 i = 0; i < addrs.length; i++) {
            bytes32 node = keccak256(abi.encodePacked(tickerManager.JSONAPIRoot(), hashes[i]));
            address addr = tickerManager.Tickers(node);
            assertEq(addr, addrs[i]);
        }

        vm.stopPrank();
    }

    function test_SetTickerBatch_RevertCases() public {
        address[] memory addrs = new address[](2);
        bytes32[] memory hashes = new bytes32[](2);

        // Test not owner
        addrs[0] = USDC;
        addrs[1] = BAYC;
        hashes[0] = getHash("USDC");
        hashes[1] = getHash("BAYC");
        vm.expectRevert(ERC173.OnlyOwner.selector);
        tickerManager.setTickerBatch(addrs, hashes);

        // Test with non-token contract
        vm.startPrank(owner);
        addrs[0] = address(12345);
        addrs[1] = BAYC;
        hashes[0] = getHash("NT");
        hashes[1] = getHash("BAYC");
        vm.expectRevert(TickerManager.NotTokenContract.selector);
        tickerManager.setTickerBatch(addrs, hashes);

        // Test with duplicate ticker
        addrs[0] = USDC;
        addrs[1] = USDC;
        hashes[0] = getHash("usdc");
        hashes[1] = getHash("usdc");
        bytes32 node = getNode("usdc");
        vm.expectRevert(abi.encodeWithSelector(TickerManager.DuplicateTicker.selector, node));
        tickerManager.setTickerBatch(addrs, hashes);
        vm.stopPrank();
    }

    function test_UpdateTicker() public {
        vm.startPrank(owner);

        // First set a ticker
        bytes32 hash = getHash("usdc");
        bytes32 node = getNode("usdc");
        tickerManager.setTicker(USDC, hash);

        // Update to a new address
        vm.expectEmit(true, true, true, true);
        emit TickerUpdated(node, WETH, 20);
        tickerManager.updateTicker(node, WETH);

        // Verify the update
        address addr = tickerManager.Tickers(node);
        assertEq(addr, WETH);

        vm.stopPrank();
    }

    function test_UpdateTicker_RevertIfNotOwner() public {
        vm.startPrank(owner);
        bytes32 hash = getHash("usdc");
        bytes32 node = getNode("usdc");
        tickerManager.setTicker(USDC, hash);
        vm.stopPrank();

        vm.startPrank(nonOwner);
        vm.expectRevert(ERC173.OnlyOwner.selector);
        tickerManager.updateTicker(node, WETH);
        vm.stopPrank();
    }
}
