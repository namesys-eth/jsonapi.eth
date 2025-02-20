// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Resolver.sol";
import "../src/Utils.sol";
import {iERC20, iERC721} from "../src/interfaces/IERC.sol";
import {LibString} from "solady/utils/LibString.sol";

contract ResolverTest is Test {
    using LibString for address;

    Resolver public resolver;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant VITALIK = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    bytes4 constant CONTENTHASH_SELECTOR = 0xbc1c58d1;

    function setUp() public {
        vm.createSelectFork("mainnet", 21836278);
        resolver = new Resolver();

        // Register featured tokens
        resolver.setTicker(true, WETH, "weth");
        resolver.setTicker(true, USDC, "usdc");
    }

    function test_ResolveSingleLabel_ENSName() public {
        // Test vitalik.jsonapi.eth
        bytes[] memory labels = new bytes[](3);
        labels[0] = bytes("vitalik");
        labels[1] = bytes("jsonapi");
        labels[2] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodePacked(CONTENTHASH_SELECTOR));
        assertTrue(result.length > 0);

        console.log("vitalik.jsonapi.eth response:");
        console.logBytes(result);
    }

    function test_ResolveSingleLabel_UserAddress() public {
        // Test 0xuser.jsonapi.eth
        bytes[] memory labels = new bytes[](3);
        labels[0] = bytes(VITALIK.toHexString());
        labels[1] = bytes("jsonapi");
        labels[2] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodePacked(CONTENTHASH_SELECTOR));
        assertTrue(result.length > 0);

        console.log("0xuser.jsonapi.eth response:");
        console.logBytes(result);
    }

    function test_ResolveSingleLabel_TokenAddress() public {
        // Test 0xtoken.jsonapi.eth
        bytes[] memory labels = new bytes[](3);
        labels[0] = bytes(WETH.toHexString());
        labels[1] = bytes("jsonapi");
        labels[2] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodePacked(CONTENTHASH_SELECTOR));
        assertTrue(result.length > 0);

        console.log("0xtoken.jsonapi.eth response:");
        console.logBytes(result);
    }

    function test_ResolveTwoLabels_UserToken() public {
        // Test vitalik.weth.jsonapi.eth
        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes("vitalik");
        labels[1] = bytes("weth");
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodePacked(CONTENTHASH_SELECTOR));
        assertTrue(result.length > 0);

        console.log("vitalik.weth.jsonapi.eth response:");
        console.logBytes(result);
    }

    function test_ResolveTwoLabels_AddressToken() public {
        // Test 0xuser.0xtoken.jsonapi.eth
        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes(VITALIK.toHexString());
        labels[1] = bytes(WETH.toHexString());
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodePacked(CONTENTHASH_SELECTOR));
        assertTrue(result.length > 0);

        console.log("0xuser.0xtoken.jsonapi.eth response:");
        console.logBytes(result);
    }

    function test_ResolveTwoLabels_TokenUser() public {
        // Test 0xtoken.0xuser.jsonapi.eth
        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes(WETH.toHexString());
        labels[1] = bytes(VITALIK.toHexString());
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodePacked(CONTENTHASH_SELECTOR));
        assertTrue(result.length > 0);

        console.log("0xtoken.0xuser.jsonapi.eth response:");
        console.logBytes(result);
    }

    function test_ResolveFeaturedTokens() public {
        // Give Vitalik some tokens for testing
        deal(WETH, VITALIK, 1 ether);
        deal(USDC, VITALIK, 1000000); // 1 USDC

        // Test vitalik.jsonapi.eth with featured tokens
        bytes[] memory labels = new bytes[](3);
        labels[0] = bytes("vitalik");
        labels[1] = bytes("jsonapi");
        labels[2] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodePacked(CONTENTHASH_SELECTOR));
        assertTrue(result.length > 0);

        console.log("vitalik.jsonapi.eth (with featured tokens) response:");
        console.logBytes(result);

        // Test 0xuser.jsonapi.eth with featured tokens
        labels[0] = bytes(VITALIK.toHexString());
        name = Encode(labels);
        result = resolver.resolve(name, abi.encodePacked(CONTENTHASH_SELECTOR));
        assertTrue(result.length > 0);

        console.log("0xuser.jsonapi.eth (with featured tokens) response:");
        console.logBytes(result);
    }

    function Encode(bytes[] memory _names) public pure returns (bytes memory) {
        uint256 i = _names.length;
        bytes memory _name = abi.encodePacked(bytes1(0));
        unchecked {
            while (i > 0) {
                --i;
                _name = bytes.concat(bytes1(uint8(_names[i].length)), _names[i], _name);
            }
        }
        return _name;
    }
}
