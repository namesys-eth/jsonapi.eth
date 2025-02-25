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

    event TickerAdded(string indexed _ticker, address indexed _addr, bytes32 node);
    event TickerRemoved(bytes32 indexed node);
    event TokenFeatured(bytes32 indexed node, bool featured);
    event CacheUpdated(bytes32 indexed node);

    TickerManager public tickerManager;
    address owner = address(1);
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

    function test_SetTicker() public {
        vm.startPrank(owner);

        // Test ERC20
        bytes32 node = getNode("usdc");
        vm.expectEmit(true, true, true, true);
        emit TickerAdded("usdc", USDC, node);
        tickerManager.setTicker(true, USDC, "usdc");

        (uint8 fid, uint64 erc, address addr, string memory name, string memory symbol, uint8 decimals) =
            tickerManager.Tickers(node);

        assertEq(fid, 1);
        assertEq(erc, 20);
        assertEq(addr, USDC);
        assertEq(name, "USD Coin");
        assertEq(symbol, "USDC");
        assertEq(decimals, 6);
        assertEq(tickerManager.Featured(1), node);

        // Test ERC721
        node = getNode("bayc");
        vm.expectEmit(true, true, true, true);
        emit TickerAdded("bayc", BAYC, node);
        tickerManager.setTicker(true, BAYC, "bayc");

        (fid, erc, addr, name, symbol, decimals) = tickerManager.Tickers(node);

        assertEq(fid, 2);
        assertEq(erc, 721);
        assertEq(addr, BAYC);
        assertEq(name, "BoredApeYachtClub");
        assertEq(symbol, "BAYC");
        assertEq(decimals, 0);
        assertEq(tickerManager.Featured(2), node);

        vm.stopPrank();
    }

    function test_SetTicker_RevertIfNotOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(ERC173.OnlyOwner.selector);
        tickerManager.setTicker(true, USDC, "usdc");
        vm.stopPrank();
    }

    function test_SetTicker_RevertIfInvalidContract() public {
        vm.startPrank(owner);
        vm.expectRevert(TickerManager.NotTokenContract.selector);
        tickerManager.setTicker(true, address(this), "TEST");

        vm.expectRevert(TickerManager.NotTokenContract.selector);
        tickerManager.setTicker(true, address(user), "TEST");
        vm.stopPrank();
    }

    function test_RemoveTicker() public {
        vm.startPrank(owner);
        bytes32 node = getNode("usdc");
        tickerManager.setTicker(true, USDC, "usdc");

        vm.expectEmit(true, false, false, false);
        emit TickerRemoved(node);
        tickerManager.removeTicker(node);

        (uint8 fid,,,,,) = tickerManager.Tickers(node);
        assertEq(fid, 0);
        vm.stopPrank();
    }

    function test_RemoveTicker_RevertIfNotOwner() public {
        vm.startPrank(owner);
        bytes32 node = getNode("usdc");
        tickerManager.setTicker(true, USDC, "usdc");
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

    function test_GetFeaturedCount() public {
        assertEq(tickerManager.getFeaturedCount(), 1); // ETH only

        vm.startPrank(owner);
        tickerManager.setTicker(true, USDC, "usdc");
        assertEq(tickerManager.getFeaturedCount(), 2);

        tickerManager.setTicker(true, BAYC, "bayc");
        assertEq(tickerManager.getFeaturedCount(), 3);

        bytes32 node = getNode("usdc");
        tickerManager.removeTicker(node);
        assertEq(tickerManager.getFeaturedCount(), 2);
        vm.stopPrank();
    }

    function test_GetFeatured() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, USDC, "usdc");
        tickerManager.setTicker(true, BAYC, "bayc");

        bytes32[] memory featured = tickerManager.getFeatured();
        assertEq(featured.length, 3); // ETH + 2 tokens
        assertEq(featured[0], getNode("eth"));
        assertEq(featured[1], getNode("usdc"));
        assertEq(featured[2], getNode("bayc"));
        vm.stopPrank();
    }

    function test_SetFeatured() public {
        assertEq(tickerManager.getFeaturedCount(), 1);

        vm.startPrank(owner);
        tickerManager.setTicker(false, USDC, "usdc");
        bytes32 node = getNode("usdc");

        tickerManager.setFeatured(node);

        (uint8 fid,,,,,) = tickerManager.Tickers(node);
        assertEq(fid, uint8(tickerManager.getFeaturedCount() - 1));
        assertEq(tickerManager.Featured(fid), node);
        vm.stopPrank();
    }

    function test_SetFeatured_RevertIfNotFound() public {
        vm.startPrank(owner);
        bytes32 node = getNode("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(TickerManager.TickerNotFound.selector, node));
        tickerManager.setFeatured(node);
        vm.stopPrank();
    }

    function test_SetFeatured_RevertIfAlreadyFeatured() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, USDC, "usdc");
        bytes32 node = getNode("usdc");

        vm.expectRevert(abi.encodeWithSelector(TickerManager.DuplicateTicker.selector, node));
        tickerManager.setFeatured(node);
        vm.stopPrank();
    }

    function test_RemoveFeatured() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, USDC, "usdc");
        bytes32 node = getNode("usdc");

        tickerManager.removeFeatured(node);

        (uint8 fid,,,,,) = tickerManager.Tickers(node);
        assertEq(fid, 0);
        assertEq(tickerManager.getFeaturedCount(), 1); // Only ETH remains
        vm.stopPrank();
    }

    function test_RemoveFeatured_RevertIfInvalidIndex() public {
        vm.startPrank(owner);
        tickerManager.setTicker(false, USDC, "usdc");
        bytes32 node = getNode("usdc");

        vm.expectRevert(TickerManager.InvalidFeaturedIndex.selector);
        tickerManager.removeFeatured(node);
        vm.stopPrank();
    }

    function test_SetCache() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, USDC, "usdc");
        bytes32 node = getNode("usdc");

        bytes memory data = abi.encode("test data");
        tickerManager.setCache(node, data);

        assertEq(tickerManager.TokenInfo(node), data);
        vm.stopPrank();
    }

    function test_SetCache_RevertIfNotFound() public {
        vm.startPrank(owner);
        bytes32 node = getNode("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(TickerManager.TickerNotFound.selector, node));
        tickerManager.setCache(node, "");
        vm.stopPrank();
    }

    function test_SetTicker_RevertIfMaxFeatured() public {
        vm.startPrank(owner);
        // Need to account for ETH already being featured
        for (uint256 i = 0; i < 254; i++) {
            tickerManager.setTicker(true, USDC, string(abi.encodePacked("usdc", vm.toString(i))));
        }

        vm.expectRevert(TickerManager.FeaturedCapacityExceeded.selector);
        tickerManager.setTicker(true, USDC, "max");
        vm.stopPrank();
    }

    function test_ETHDefaults() public view {
        bytes32 ethNode = keccak256(abi.encodePacked(tickerManager.JSONAPIRoot(), keccak256("eth")));
        (uint8 fid, uint64 erc, address addr, string memory name, string memory symbol, uint8 decimals) =
            tickerManager.Tickers(ethNode);

        assertEq(fid, 0);
        assertEq(erc, 20);
        assertEq(addr, address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));
        assertEq(name, "Ethereum");
        assertEq(symbol, "ETH");
        assertEq(decimals, 18);
        assertEq(tickerManager.Featured(0), ethNode);
    }

    function test_SetTicker_RevertIfDuplicate() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, USDC, "usdc");

        vm.expectRevert(abi.encodeWithSelector(TickerManager.DuplicateTicker.selector, getNode("usdc")));
        tickerManager.setTicker(true, USDC, "usdc");
        vm.stopPrank();
    }

    function test_RemoveTicker_LastFeatured() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, USDC, "usdc");
        tickerManager.setTicker(true, BAYC, "bayc");

        bytes32 node = getNode("usdc");
        tickerManager.removeTicker(node);

        // Check that TEST2 was moved to TEST1's position
        bytes32 baycNode = getNode("bayc");
        (uint8 fid,,,,,) = tickerManager.Tickers(baycNode);
        assertEq(fid, 1);
        assertEq(tickerManager.Featured(1), baycNode);
        vm.stopPrank();
    }

    function test_RemoveFeatured_LastElement() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, USDC, "usdc");
        tickerManager.setTicker(true, BAYC, "bayc");

        bytes32 node = getNode("usdc");
        tickerManager.removeFeatured(node);

        // Check that array was properly shortened
        vm.expectRevert();
        tickerManager.Featured(2);
        vm.stopPrank();
    }

    function test_SetTicker_NonFeatured() public {
        vm.startPrank(owner);
        bytes32 node = getNode("usdc");
        tickerManager.setTicker(false, USDC, "usdc"); // Set as non-featured

        (uint8 fid, uint64 erc, address addr, string memory name, string memory symbol, uint8 decimals) =
            tickerManager.Tickers(node);

        assertEq(fid, 0); // Should not be featured
        assertEq(erc, 20);
        assertEq(addr, USDC);
        assertEq(name, "USD Coin");
        assertEq(symbol, "USDC");
        assertEq(decimals, 6);
        vm.stopPrank();
    }

    function test_SetTicker_EmptyCode() public {
        vm.startPrank(owner);
        address emptyAddr = address(0x1234);
        vm.expectRevert(TickerManager.NotTokenContract.selector);
        tickerManager.setTicker(true, emptyAddr, "TEST");
        vm.stopPrank();
    }

    function test_SetCache_MultipleUpdates() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, USDC, "usdc");
        bytes32 node = getNode("usdc");

        bytes memory data1 = abi.encode("data1");
        tickerManager.setCache(node, data1);
        assertEq(tickerManager.TokenInfo(node), data1);

        bytes memory data2 = abi.encode("data2");
        tickerManager.setCache(node, data2);
        assertEq(tickerManager.TokenInfo(node), data2);
        vm.stopPrank();
    }

    function test_RemoveTicker_NonFeatured() public {
        vm.startPrank(owner);
        tickerManager.setTicker(false, USDC, "usdc"); // Non-featured ticker
        bytes32 node = getNode("usdc");

        tickerManager.removeTicker(node);

        (uint8 fid,,,,,) = tickerManager.Tickers(node);
        assertEq(fid, 0);
        assertEq(tickerManager.getFeaturedCount(), 1); // Only ETH remains
        vm.stopPrank();
    }

    function test_SetFeatured_MaxCapacity() public {
        vm.startPrank(owner);
        // Fill up to max capacity - 1 (accounting for ETH)
        for (uint256 i = 0; i < 254; i++) {
            tickerManager.setTicker(false, USDC, string(abi.encodePacked("usdc", vm.toString(i))));
            tickerManager.setFeatured(getNode(string(abi.encodePacked("usdc", vm.toString(i)))));
        }

        // Try to feature one more
        tickerManager.setTicker(false, USDC, "LAST");
        bytes32 lastNode = getNode("LAST");
        vm.expectRevert(TickerManager.FeaturedCapacityExceeded.selector);
        tickerManager.setFeatured(lastNode);
        vm.stopPrank();
    }

    function test_RemoveFeatured_UpdatesIndexes() public {
        vm.startPrank(owner);
        // Add three tokens
        tickerManager.setTicker(true, USDC, "usdc1");
        tickerManager.setTicker(true, USDC, "usdc2");
        tickerManager.setTicker(true, USDC, "usdc3");

        bytes32 node2 = getNode("usdc2");
        tickerManager.removeFeatured(node2);

        // Check TEST3 moved to TEST2's position
        bytes32 node3 = getNode("usdc3");
        (uint8 fid,,,,,) = tickerManager.Tickers(node3);
        assertEq(fid, 2);
        assertEq(tickerManager.Featured(2), node3);
        vm.stopPrank();
    }

    function test_GetFeaturedUser() public {
        // Test with no featured tokens (except ETH)
        bytes memory result = tickerManager.getFeaturedUser(user);
        assertFalse(LibString.contains(string(result), '"USDC":'));
        assertFalse(LibString.contains(string(result), '"BAYC":'));
        assertTrue(LibString.contains(string(result), '"ETH":'));
        assertTrue(LibString.contains(string(result), '"ENS":'));

        vm.startPrank(owner);
        tickerManager.setTicker(true, USDC, "USDC");
        vm.stopPrank();

        vm.startPrank(0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341);
        iERC20(USDC).transfer(user, 1e8);
        vm.stopPrank();

        result = tickerManager.getFeaturedUser(user);
        assertTrue(LibString.contains(string(result), '"USDC":'));

        vm.startPrank(owner);
        tickerManager.setTicker(true, BAYC, "BAYC");
        vm.stopPrank();

        vm.startPrank(iERC721(BAYC).ownerOf(1));
        iERC721(BAYC).transferFrom(address(iERC721(BAYC).ownerOf(1)), user, 1);
        vm.stopPrank();
        result = tickerManager.getFeaturedUser(user);
        assertTrue(LibString.contains(string(result), '"BAYC":'));
    }

    function test_SetTickerBatch() public {
        vm.startPrank(owner);

        address[] memory addrs = new address[](2);
        string[] memory tickers = new string[](2);

        // Setup test data
        addrs[0] = USDC;
        addrs[1] = BAYC;
        tickers[0] = "USDC";
        tickers[1] = "BAYC";

        // Test batch setting
        tickerManager.setTickerBatch(addrs, tickers);

        // Verify each ticker
        for (uint256 i = 0; i < addrs.length; i++) {
            bytes32 node = getNode(tickers[i]);
            (uint8 featured, uint16 erc, address addr,,,) = tickerManager.Tickers(node);
            assertEq(featured, 0);
            assertEq(addr, addrs[i]);
            assertEq(erc, addrs[i] == BAYC ? 721 : 20);
        }

        vm.stopPrank();
    }

    function test_SetTickerBatch_RevertCases() public {
        address[] memory addrs = new address[](2);
        string[] memory tickers = new string[](2);

        // Test not owner
        addrs[0] = USDC;
        addrs[1] = BAYC;
        tickers[0] = "USDC";
        tickers[1] = "BAYC";
        vm.expectRevert(ERC173.OnlyOwner.selector);
        tickerManager.setTickerBatch(addrs, tickers);

        // Test with non-token contract
        vm.startPrank(owner);
        addrs[0] = address(12345);
        addrs[1] = BAYC;
        tickers[0] = "NT";
        tickers[1] = "BAYC";
        vm.expectRevert(TickerManager.NotTokenContract.selector);
        tickerManager.setTickerBatch(addrs, tickers);

        // Test with duplicate ticker
        addrs[0] = USDC;
        addrs[1] = USDC;
        tickers[0] = "usdc";
        tickers[1] = "usdc";
        bytes32 node = getNode("usdc");
        vm.expectRevert(abi.encodeWithSelector(TickerManager.DuplicateTicker.selector, node));
        tickerManager.setTickerBatch(addrs, tickers);
        vm.stopPrank();
    }

    function test_SetFeaturedBatch() public {
        vm.startPrank(owner);

        // First set some tickers
        tickerManager.setTicker(false, USDC, "usdc");
        tickerManager.setTicker(false, BAYC, "bayc");

        // Get their nodes
        bytes32[] memory nodes = new bytes32[](2);
        nodes[0] = getNode("usdc");
        nodes[1] = getNode("bayc");

        // Test batch featuring
        tickerManager.setFeaturedBatch(nodes);

        // Verify each is featured
        for (uint256 i = 0; i < nodes.length; i++) {
            (uint8 featured,,,,,) = tickerManager.Tickers(nodes[i]);
            assertEq(featured, i + 1); // +1 because ETH is at index 0
            assertEq(tickerManager.Featured(i + 1), nodes[i]);
        }

        vm.stopPrank();
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_SetFeaturedBatch_RevertCases() public {
        bytes32[] memory nodes = new bytes32[](2);

        // Test not owner
        nodes[0] = getNode("TK1");
        vm.expectRevert(ERC173.OnlyOwner.selector);
        tickerManager.setFeaturedBatch(nodes);

        vm.startPrank(owner);

        // Test with non-existent ticker
        nodes[0] = getNode("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(TickerManager.TickerNotFound.selector, nodes[0]));
        tickerManager.setFeaturedBatch(nodes);

        // Test with already featured ticker
        tickerManager.setTicker(true, USDC, "usdc");
        nodes[0] = getNode("usdc");
        vm.expectRevert(abi.encodeWithSelector(TickerManager.DuplicateTicker.selector, nodes[0]));
        tickerManager.setFeaturedBatch(nodes);

        // Test exceeding max capacity
        nodes = new bytes32[](255); // ETH + 255 would exceed uint8 max
        for (uint256 i = 0; i < 255; i++) {
            string memory ticker = string(abi.encodePacked("usdc", vm.toString(i)));
            tickerManager.setTicker(false, USDC, ticker);
            nodes[i] = getNode(ticker);
        }
        vm.expectRevert(TickerManager.FeaturedCapacityExceeded.selector);
        tickerManager.setFeaturedBatch(nodes);

        vm.stopPrank();
    }
}
