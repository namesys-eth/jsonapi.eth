// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./mocks/SoladyToken.sol";
import "./mocks/SoladyNFT.sol";
import "../src/TickerManager.sol";
import "../src/Utils.sol";
import "./mocks/NonToken.sol";
import {iERC20, iERC721} from "../src/interfaces/IERC.sol";

contract TickerManagerTest is Test {
    event TickerAdded(string indexed _ticker, address indexed _addr, bytes32 node);
    event TickerRemoved(bytes32 indexed node);
    event TokenFeatured(bytes32 indexed node, bool featured);
    event CacheUpdated(bytes32 indexed node);

    TickerManager public tickerManager;
    SoladyToken public token;
    SoladyNFT public nft;
    NonToken public nonToken;
    address owner = address(1);
    address nonOwner = address(2);
    address user = address(3);

    function setUp() public {
        vm.startPrank(owner);
        tickerManager = new TickerManager();
        token = new SoladyToken();
        nft = new SoladyNFT();
        nonToken = new NonToken();
        vm.stopPrank();
    }

    function getNode(string memory ticker) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(tickerManager.JSONAPIRoot(), keccak256(bytes(ticker))));
    }

    function test_SetTicker() public {
        vm.startPrank(owner);

        // Test ERC20
        bytes32 node = getNode("TEST");
        vm.expectEmit(true, true, true, true);
        emit TickerAdded("TEST", address(token), node);
        tickerManager.setTicker(true, address(token), "TEST");

        (uint8 fid, uint64 erc, address addr, string memory name, string memory symbol, uint8 decimals) =
            tickerManager.Tickers(node);

        assertEq(fid, 1);
        assertEq(erc, 20);
        assertEq(addr, address(token));
        assertEq(name, "Test Token");
        assertEq(symbol, "TEST");
        assertEq(decimals, 18);
        assertEq(tickerManager.Featured(1), node);

        // Test ERC721
        node = getNode("TNFT");
        vm.expectEmit(true, true, true, true);
        emit TickerAdded("TNFT", address(nft), node);
        tickerManager.setTicker(true, address(nft), "TNFT");

        (fid, erc, addr, name, symbol, decimals) = tickerManager.Tickers(node);

        assertEq(fid, 2);
        assertEq(erc, 721);
        assertEq(addr, address(nft));
        assertEq(name, "Test NFT");
        assertEq(symbol, "TNFT");
        assertEq(decimals, 0);
        assertEq(tickerManager.Featured(2), node);

        vm.stopPrank();
    }

    function test_SetTicker_RevertIfNotOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(ERC173.OnlyOwner.selector);
        tickerManager.setTicker(true, address(token), "TEST");
        vm.stopPrank();
    }

    function test_SetTicker_RevertIfInvalidContract() public {
        vm.startPrank(owner);
        vm.expectRevert(TickerManager.NotTokenContract.selector);
        tickerManager.setTicker(true, address(nonToken), "TEST");
        vm.stopPrank();
    }

    function test_RemoveTicker() public {
        vm.startPrank(owner);
        bytes32 node = getNode("TEST");
        tickerManager.setTicker(true, address(token), "TEST");

        vm.expectEmit(true, false, false, false);
        emit TickerRemoved(node);
        tickerManager.removeTicker(node);

        (uint8 fid,,,,,) = tickerManager.Tickers(node);
        assertEq(fid, 0);
        vm.stopPrank();
    }

    function test_RemoveTicker_RevertIfNotOwner() public {
        vm.startPrank(owner);
        bytes32 node = getNode("TEST");
        tickerManager.setTicker(true, address(token), "TEST");
        vm.stopPrank();

        vm.startPrank(nonOwner);
        vm.expectRevert(ERC173.OnlyOwner.selector);
        tickerManager.removeTicker(node);
        vm.stopPrank();
    }

    function test_RemoveTicker_RevertIfNotExists() public {
        vm.startPrank(owner);
        bytes32 node = getNode("TEST");
        vm.expectRevert(abi.encodeWithSelector(TickerManager.TickerNotFound.selector, node));
        tickerManager.removeTicker(node);
        vm.stopPrank();
    }

    function test_GetFeaturedCount() public {
        assertEq(tickerManager.getFeaturedCount(), 1); // ETH only

        vm.startPrank(owner);
        tickerManager.setTicker(true, address(token), "TEST");
        assertEq(tickerManager.getFeaturedCount(), 2);

        tickerManager.setTicker(true, address(nft), "TNFT");
        assertEq(tickerManager.getFeaturedCount(), 3);

        bytes32 node = getNode("TEST");
        tickerManager.removeTicker(node);
        assertEq(tickerManager.getFeaturedCount(), 2);
        vm.stopPrank();
    }

    function test_GetFeatured() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, address(token), "TEST");
        tickerManager.setTicker(true, address(nft), "TNFT");

        bytes32[] memory featured = tickerManager.getFeatured();
        assertEq(featured.length, 3); // ETH + 2 tokens
        assertEq(featured[0], getNode("eth"));
        assertEq(featured[1], getNode("TEST"));
        assertEq(featured[2], getNode("TNFT"));
        vm.stopPrank();
    }

    function test_SetFeatured() public {
        vm.startPrank(owner);
        tickerManager.setTicker(false, address(token), "TEST");
        bytes32 node = getNode("TEST");

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
        tickerManager.setTicker(true, address(token), "TEST");
        bytes32 node = getNode("TEST");

        vm.expectRevert(abi.encodeWithSelector(TickerManager.DuplicateTicker.selector, node));
        tickerManager.setFeatured(node);
        vm.stopPrank();
    }

    function test_RemoveFeatured() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, address(token), "TEST");
        bytes32 node = getNode("TEST");

        tickerManager.removeFeatured(node);

        (uint8 fid,,,,,) = tickerManager.Tickers(node);
        assertEq(fid, 0);
        assertEq(tickerManager.getFeaturedCount(), 1); // Only ETH remains
        vm.stopPrank();
    }

    function test_RemoveFeatured_RevertIfInvalidIndex() public {
        vm.startPrank(owner);
        tickerManager.setTicker(false, address(token), "TEST");
        bytes32 node = getNode("TEST");

        vm.expectRevert(TickerManager.InvalidFeaturedIndex.selector);
        tickerManager.removeFeatured(node);
        vm.stopPrank();
    }

    function test_SetCache() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, address(token), "TEST");
        bytes32 node = getNode("TEST");

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
            tickerManager.setTicker(true, address(token), string(abi.encodePacked("TEST", vm.toString(i))));
        }

        vm.expectRevert(TickerManager.FeaturedCapacityExceeded.selector);
        tickerManager.setTicker(true, address(token), "OVER");
        vm.stopPrank();
    }

    function test_ETHDefaults() public {
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
        tickerManager.setTicker(true, address(token), "TEST");

        vm.expectRevert(abi.encodeWithSelector(TickerManager.DuplicateTicker.selector, getNode("TEST")));
        tickerManager.setTicker(true, address(token), "TEST");
        vm.stopPrank();
    }

    function test_RemoveTicker_LastFeatured() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, address(token), "TEST1");
        tickerManager.setTicker(true, address(token), "TEST2");

        bytes32 node = getNode("TEST1");
        tickerManager.removeTicker(node);

        // Check that TEST2 was moved to TEST1's position
        bytes32 test2Node = getNode("TEST2");
        (uint8 fid,,,,,) = tickerManager.Tickers(test2Node);
        assertEq(fid, 1);
        assertEq(tickerManager.Featured(1), test2Node);
        vm.stopPrank();
    }

    function test_RemoveFeatured_LastElement() public {
        vm.startPrank(owner);
        tickerManager.setTicker(true, address(token), "TEST1");
        tickerManager.setTicker(true, address(token), "TEST2");

        bytes32 node = getNode("TEST2");
        tickerManager.removeFeatured(node);

        // Check that array was properly shortened
        vm.expectRevert();
        tickerManager.Featured(2);
        vm.stopPrank();
    }

    function test_SetTicker_NonFeatured() public {
        vm.startPrank(owner);
        bytes32 node = getNode("TEST");
        tickerManager.setTicker(false, address(token), "TEST"); // Set as non-featured

        (uint8 fid, uint64 erc, address addr, string memory name, string memory symbol, uint8 decimals) =
            tickerManager.Tickers(node);

        assertEq(fid, 0); // Should not be featured
        assertEq(erc, 20);
        assertEq(addr, address(token));
        assertEq(name, "Test Token");
        assertEq(symbol, "TEST");
        assertEq(decimals, 18);
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
        tickerManager.setTicker(true, address(token), "TEST");
        bytes32 node = getNode("TEST");

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
        tickerManager.setTicker(false, address(token), "TEST"); // Non-featured ticker
        bytes32 node = getNode("TEST");

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
            tickerManager.setTicker(false, address(token), string(abi.encodePacked("TEST", vm.toString(i))));
            tickerManager.setFeatured(getNode(string(abi.encodePacked("TEST", vm.toString(i)))));
        }

        // Try to feature one more
        tickerManager.setTicker(false, address(token), "LAST");
        bytes32 lastNode = getNode("LAST");
        vm.expectRevert(TickerManager.FeaturedCapacityExceeded.selector);
        tickerManager.setFeatured(lastNode);
        vm.stopPrank();
    }

    function test_RemoveFeatured_UpdatesIndexes() public {
        vm.startPrank(owner);
        // Add three tokens
        tickerManager.setTicker(true, address(token), "TEST1");
        tickerManager.setTicker(true, address(token), "TEST2");
        tickerManager.setTicker(true, address(token), "TEST3");

        bytes32 node2 = getNode("TEST2");
        tickerManager.removeFeatured(node2);

        // Check TEST3 moved to TEST2's position
        bytes32 node3 = getNode("TEST3");
        (uint8 fid,,,,,) = tickerManager.Tickers(node3);
        assertEq(fid, 2);
        assertEq(tickerManager.Featured(2), node3);
        vm.stopPrank();
    }

    function test_GetFeaturedUser_EdgeCases() public {
        vm.startPrank(owner);

        // Test with no featured tokens (except ETH)
        bytes memory result = tickerManager.getFeaturedUser(user);
        assertTrue(result.length > 0);

        // Test with zero balances
        tickerManager.setTicker(true, address(token), "TK1");
        result = tickerManager.getFeaturedUser(user);
        assertTrue(result.length > 0);

        // Test with max balances
        deal(address(token), user, type(uint256).max);
        result = tickerManager.getFeaturedUser(user);
        assertTrue(result.length > 0);

        // Test with mix of ERC20 and ERC721
        tickerManager.setTicker(true, address(nft), "NFT1");
        nft.mint(user, 1);
        result = tickerManager.getFeaturedUser(user);
        assertTrue(result.length > 0);

        vm.stopPrank();
    }

    function test_SetTickerBatch() public {
        vm.startPrank(owner);

        address[] memory addrs = new address[](2);
        string[] memory tickers = new string[](2);

        // Setup test data
        addrs[0] = address(token);
        addrs[1] = address(nft);
        tickers[0] = "TK1";
        tickers[1] = "NFT1";

        // Test batch setting
        tickerManager.setTickerBatch(addrs, tickers);

        // Verify each ticker
        for (uint256 i = 0; i < addrs.length; i++) {
            bytes32 node = getNode(tickers[i]);
            (uint8 featured, uint16 erc, address addr,,,) = tickerManager.Tickers(node);
            assertEq(featured, 0);
            assertEq(addr, addrs[i]);
            assertEq(erc, addrs[i] == address(nft) ? 721 : 20);
        }

        vm.stopPrank();
    }

    function test_SetTickerBatch_RevertCases() public {
        address[] memory addrs = new address[](2);
        string[] memory tickers = new string[](2);

        // Test not owner
        addrs[0] = address(token);
        addrs[1] = address(token);
        tickers[0] = "TK1";
        tickers[1] = "TK2";
        vm.expectRevert(ERC173.OnlyOwner.selector);
        tickerManager.setTickerBatch(addrs, tickers);

        // Test with non-token contract
        vm.startPrank(owner);
        addrs[0] = address(nonToken);
        addrs[1] = address(token);
        tickers[0] = "NT";
        tickers[1] = "TK1";
        vm.expectRevert(TickerManager.NotTokenContract.selector);
        tickerManager.setTickerBatch(addrs, tickers);

        // Test with duplicate ticker
        addrs[0] = address(token);
        addrs[1] = address(token);
        tickers[0] = "SAME";
        tickers[1] = "SAME";
        bytes32 node = getNode("SAME");
        vm.expectRevert(abi.encodeWithSelector(TickerManager.DuplicateTicker.selector, node));
        tickerManager.setTickerBatch(addrs, tickers);
        vm.stopPrank();
    }

    function test_SetFeaturedBatch() public {
        vm.startPrank(owner);

        // First set some tickers
        tickerManager.setTicker(false, address(token), "TK1");
        tickerManager.setTicker(false, address(nft), "NFT1");

        // Get their nodes
        bytes32[] memory nodes = new bytes32[](2);
        nodes[0] = getNode("TK1");
        nodes[1] = getNode("NFT1");

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
        tickerManager.setTicker(true, address(token), "TK1");
        nodes[0] = getNode("TK1");
        vm.expectRevert(abi.encodeWithSelector(TickerManager.DuplicateTicker.selector, nodes[0]));
        tickerManager.setFeaturedBatch(nodes);

        // Test exceeding max capacity
        nodes = new bytes32[](255); // ETH + 255 would exceed uint8 max
        for (uint256 i = 0; i < 255; i++) {
            string memory ticker = string(abi.encodePacked("T", vm.toString(i)));
            tickerManager.setTicker(false, address(token), ticker);
            nodes[i] = getNode(ticker);
        }
        vm.expectRevert(TickerManager.FeaturedCapacityExceeded.selector);
        tickerManager.setFeaturedBatch(nodes);

        vm.stopPrank();
    }
}
