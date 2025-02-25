// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Resolver.sol";
import "../src/Utils.sol";
import {iERC20, iERC721} from "../src/interfaces/IERC.sol";
import {LibString} from "solady/utils/LibString.sol";
import {iResolver} from "../src/interfaces/IENS.sol";

contract ResolverTest is Test {
    using LibString for address;
    using LibString for uint256;

    Resolver public resolver;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant VITALIK = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    address constant BAYC = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;

    address publicResolver = 0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41;
    address ens721 = 0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85;
    address ensWrapper = 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401;
        
    function setUp() public {
        vm.createSelectFork("mainnet", 21836278);
        resolver = new Resolver(publicResolver, ens721, ensWrapper);

        // Register featured tokens
        resolver.setTicker(true, WETH, "weth");
        resolver.setTicker(true, USDC, "usdc");
        resolver.setTicker(true, BAYC, "bayc");
    }

    function test_ResolveSingleLabel_ENSName() public view {
        // Test vitalik.jsonapi.eth
        bytes[] memory labels = new bytes[](3);
        labels[0] = bytes("vitalik");
        labels[1] = bytes("jsonapi");
        labels[2] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertTrue(result.length > 0);

        console.log("vitalik.jsonapi.eth response:");
        console.logBytes(result);
    }

    function test_ResolveSingleLabel_UserAddress() public view {
        // Test 0xuser.jsonapi.eth
        bytes[] memory labels = new bytes[](3);
        labels[0] = bytes(VITALIK.toHexString());
        labels[1] = bytes("jsonapi");
        labels[2] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertTrue(result.length > 0);

        console.log("0xuser.jsonapi.eth response:");
        console.logBytes(result);
    }

    function test_ResolveSingleLabel_TokenAddress() public view {
        // Test 0xtoken.jsonapi.eth
        bytes[] memory labels = new bytes[](3);
        labels[0] = bytes(WETH.toHexString());
        labels[1] = bytes("jsonapi");
        labels[2] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertTrue(result.length > 0);

        console.log("0xtoken.jsonapi.eth response:");
        console.logBytes(result);
    }

    function test_ResolveTwoLabels_UserToken() public view {
        // Test vitalik.weth.jsonapi.eth
        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes("vitalik");
        labels[1] = bytes("weth");
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertTrue(result.length > 0);

        console.log("vitalik.weth.jsonapi.eth response:");
        console.logBytes(result);
    }

    function test_ResolveTwoLabels_AddressToken() public view {
        // Test 0xuser.0xtoken.jsonapi.eth
        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes(VITALIK.toHexString());
        labels[1] = bytes(WETH.toHexString());
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertTrue(result.length > 0);

        console.log("0xuser.0xtoken.jsonapi.eth response:");
        console.logBytes(result);
    }

    function test_ResolveTwoLabels_TokenUser() public {
        // Test user.token (vitalik.weth.jsonapi.eth)
        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes(VITALIK.toHexString());
        labels[1] = bytes(WETH.toHexString());
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertTrue(result.length > 0);

        console.log("user.token.jsonapi.eth response:");
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
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertTrue(result.length > 0);

        console.log("vitalik.jsonapi.eth (with featured tokens) response:");
        console.logBytes(result);

        // Test 0xuser.jsonapi.eth with featured tokens
        labels[0] = bytes(VITALIK.toHexString());
        name = Encode(labels);
        result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertTrue(result.length > 0);

        console.log("0xuser.jsonapi.eth (with featured tokens) response:");
        console.logBytes(result);
    }

    function test_ResolveTwoLabels_NFTTokenId() public {
        // Test with BAYC token #1234 owned by whale
        uint256 tokenId = 1234;

        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes(tokenId.toString());
        labels[1] = bytes(BAYC.toHexString());
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertTrue(result.length > 0);

        console.log("1234.bayc.jsonapi.eth response:");
        console.logBytes(result);
    }

    function test_ResolveTwoLabels_InvalidCombinations() public {
        // Test EOA.EOA case
        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes(VITALIK.toHexString());
        labels[1] = bytes(address(0xdead).toHexString());
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        // Should return error for invalid token type
        assertTrue(LibString.contains(string(result), "Invalid Token Type"));

        // Test token.token case (ERC20.ERC20)
        labels[0] = bytes(WETH.toHexString());
        labels[1] = bytes(USDC.toHexString());
        name = Encode(labels);
        vm.expectRevert(Resolver.BadRequest.selector);
        resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
    }

    function test_ResolveTwoLabels_ZeroAddress() public view {
        // Test with zero address as L1
        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes(address(0).toHexString());
        labels[1] = bytes(WETH.toHexString());
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertTrue(LibString.contains(string(result), "Zero Address"));

        // Test with zero address as L2
        labels[0] = bytes(VITALIK.toHexString());
        labels[1] = bytes(address(0).toHexString());
        name = Encode(labels);
        result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertTrue(LibString.contains(string(result), "Zero Address"));
    }

    function test_ResolveBase_JsonapiEth() public {
        bytes[] memory labels = new bytes[](2);
        labels[0] = bytes("jsonapi");
        labels[1] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertGt(result.length, 0);
    }

    function test_ResolveUnsupportedSelector() public {
        // Test with unsupported selector
        bytes[] memory labels = new bytes[](3);
        labels[0] = bytes("vitalik");
        labels[1] = bytes("jsonapi");
        labels[2] = bytes("eth");

        bytes memory name = Encode(labels);
        vm.expectRevert(Resolver.OnlyContentHashSupported.selector);
        resolver.resolve(name, abi.encodeWithSelector(iResolver.addr.selector, bytes32(0)));
    }

    function test_ResolveNotImplemented() public {
        // Test with invalid label count
        bytes[] memory labels = new bytes[](5);
        labels[0] = bytes("extra");
        labels[1] = bytes("vitalik");
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");
        labels[4] = bytes("com");

        bytes memory name = Encode(labels);
        vm.expectRevert(
            abi.encodeWithSelector(
                Resolver.NotImplemented.selector, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0))
            )
        );
        resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
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
