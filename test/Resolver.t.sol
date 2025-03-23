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
    using Utils for *;

    Resolver public resolver;
    bytes4 public selector = iResolver.contenthash.selector;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant VITALIK = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    address constant BAYC = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;

    address publicResolver = 0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41;
    address ens721 = 0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85;
    address ensWrapper = 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401;

    /**
     * @notice Extract JSON data from response using assembly
     * @param responseBytes The raw response bytes
     * @return The extracted JSON as a string
     */
    function extractJsonFromResponse(bytes calldata responseBytes) external view returns (string memory) {
        if (responseBytes[0] == bytes1("{")) {
            return string(responseBytes);
        }
        uint256 start = 7;
        bytes memory _decoded = abi.decode(responseBytes, (bytes));
        if (_decoded.length > 7 && uint8(_decoded[6]) >= 128) {
            start = 8;
        }
        // If not contenthash or decoding failed, try direct JSON string
        return string(this.decodeContentHash(_decoded, start));
    }

    /**
     * @notice Decode contenthash format (abi.encode(abi.encodePacked(hex"e30101800400", varint(length), data)))
     * @param responseBytes The raw response bytes
     * @return The extracted JSON as a string
     */
    function decodeContentHash(bytes calldata responseBytes, uint256 start) external pure returns (string memory) {
        return string(responseBytes[start:]);
    }

    function setUp() public {
        //vm.createSelectFork("mainnet", 21836278);
        resolver = new Resolver();

        // Register tokens
        resolver.setTicker(WETH, keccak256(bytes("weth")));
        resolver.setTicker(USDC, keccak256(bytes("usdc")));
        resolver.setTicker(BAYC, keccak256(bytes("bayc")));
    }

    function test_ResolveSingleLabel_ENSName() public view {
        // Test vitalik.jsonapi.eth
        /*
        bytes[] memory labels = new bytes[](3);
        labels[0] = bytes("vitalik");
        labels[1] = bytes("jsonapi");
        labels[2] = bytes("eth");
        */
        bytes memory name =
            abi.encodePacked(uint8(7), bytes("vitalik"), uint8(7), bytes("jsonapi"), uint8(3), bytes("eth"), bytes1(0));
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertGt(result.length, 0);
        string memory actual = this.extractJsonFromResponse(result);

        //forgefmt:disable-next-item
        string memory expected = 
        '{' 
            '"ok":true,'
            '"time":"1739434199",' 
            '"block":"21836278",' 
            '"erc":0,' 
            '"user":{'
                '"address":"0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",'
                '"name":"vitalik.eth",'
                '"balance":"964.458627",'
                '"price":"2682.386649"'
            '}' 
        '}';

        assertEq(actual, expected);
    }

    function test_ResolveSingleLabel_UserAddress() public view {
        // Test 0xuser.jsonapi.eth
        bytes[] memory labels = new bytes[](3);
        labels[0] = bytes(VITALIK.toHexString());
        labels[1] = bytes("jsonapi");
        labels[2] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertGt(result.length, 0);
        string memory actual = this.extractJsonFromResponse(result);
        //forgefmt:disable-next-item
        string memory expected = 
        '{' 
            '"ok":true,'
            '"time":"1739434199",'
            '"block":"21836278",'
            '"erc":0,'
            '"user":{'
                '"address":"0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",'
                '"name":"vitalik.eth",'
                '"balance":"964.458627",'
                '"price":"2682.386649"'
            '}'
        '}';
        assertEq(actual, expected);
    }

    function test_ResolveSingleLabel_TokenAddress() public {
        // Test 0xtoken.jsonapi.eth

        bytes memory name = abi.encodePacked(
            uint8(42),
            bytes("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"),
            uint8(7),
            bytes("jsonapi"),
            uint8(3),
            bytes("eth"),
            bytes1(0)
        );

        // Temporarily making non-view to allow gas metering control
        //vm.pauseGasMetering();

        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));

        //

        //string memory actual = this.extractJsonFromResponse(result);
        //forgefmt:disable-next-item
        string memory data = 
        '{'
            '"ok":true,'
            '"time":"1739434199",'
            '"block":"21836278",'
            '"erc":20,'
            '"token":{'
                '"contract":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",'
                '"decimals":18,'
                '"marketcap":"7911248370.108695",'
                '"name":"Wrapped Ether",'
                '"price":"2682.386649",'
                '"supply":"2949331.847091",'
                '"symbol":"WETH"'
            '}'
        '}';
        bytes memory expected = abi.encode(abi.encodePacked(hex"e30101800400", varintTester(bytes(data).length), data));

        assertEq(result, expected);
    }

    function varintTester(uint256 length) internal pure returns (bytes memory) {
        return (length < 128)
            ? abi.encodePacked(uint8(length))
            : abi.encodePacked(bin((length % 128) + 128), bin(length / 128));
    }

    function bin(uint256 x) private pure returns (bytes memory b) {
        if (x > 0) return abi.encodePacked(bin(x / 256), bytes1(uint8(x % 256)));
    }

    function test_ResolveTwoLabels_UserToken() public view {
        // Test vitalik.weth.jsonapi.eth
        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes("vitalik");
        labels[1] = bytes("weth");
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = abi.encodePacked(
            uint8(7),
            bytes("vitalik"),
            uint8(4),
            bytes("weth"),
            uint8(7),
            bytes("jsonapi"),
            uint8(3),
            bytes("eth"),
            bytes1(0)
        );
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        //forgefmt:disable-next-item
        string memory data = 
            '{' 
                '"ok":true,'
                '"time":"1739434199",'
                '"block":"21836278",'
                '"erc":20,'
                '"token":{'
                    '"contract":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",'
                    '"decimals":18,'
                    '"price":"2682.386649",'
                    '"symbol":"WETH",'
                    '"user":{'
                        '"address":"0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",'
                        '"balance":"16.320309"' 
                    '}'
                '}'
            '}';
        bytes memory expected = abi.encode(abi.encodePacked(hex"e30101800400", varintTester(bytes(data).length), data));
        assertEq(result, expected);
    }

    function test_ResolveTwoLabels_AddressToken() public {
        // Test 0xuser.0xtoken.jsonapi.eth
        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes(VITALIK.toHexString());
        labels[1] = bytes(WETH.toHexString());
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);

        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));

        assertGt(result.length, 0);

        string memory actual = this.extractJsonFromResponse(result);

        // forgefmt: disable-next-item
        string memory expected = 
            '{'
                '"ok":true,'
                '"time":"1739434199",'
                '"block":"21836278",'
                '"erc":20,'
                '"token":{'
                    '"contract":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",'
                    '"decimals":18,'
                    '"price":"2682.386649",'
                    '"symbol":"WETH",'
                    '"user":{'
                        '"address":"0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",'
                        '"balance":"16.320309"' 
                    '}' 
                '}' 
            '}';
        assertEq(actual, expected);

        labels[0] = bytes(WETH.toHexString());
        labels[1] = bytes(VITALIK.toHexString());
        name = Encode(labels);

        result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));

        actual = this.extractJsonFromResponse(result);
        assertEq(actual, expected);
    }

    function test_ResolveTwoLabels_TokenUser() public view {
        // Test user.token (vitalik.weth.jsonapi.eth)
        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes("vitalik");
        labels[1] = bytes(WETH.toHexString());
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertTrue(result.length > 0);

        string memory actual = this.extractJsonFromResponse(result);
        // forgefmt: disable-next-item
        string memory expected = 
            '{'
                '"ok":true,'
                '"time":"1739434199",'
                '"block":"21836278",'
                '"erc":20,'
                '"token":{'
                    '"contract":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",'
                    '"decimals":18,'
                    '"price":"2682.386649",'
                    '"symbol":"WETH",'
                    '"user":{'
                        '"address":"0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",'
                        '"balance":"16.320309"' 
                    '}' 
                '}' 
            '}';
        assertEq(actual, expected);
    }

    function test_ResolveTwoLabels_NFTTokenId() public view {
        // Test with BAYC token #1234
        uint256 tokenId = 1234;

        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes(tokenId.toString());
        labels[1] = bytes(BAYC.toHexString());
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        assertGt(result.length, 0);

        string memory actual = this.extractJsonFromResponse(result);

        // forgefmt: disable-next-item
        string memory expected = 
            '{'
                '"ok":true,'
                '"time":"1739434199",'
                '"block":"21836278",'
                '"erc":721,'
                '"token":{'
                    '"contract":"0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",'
                    '"id":"1234",'
                    '"name":"BoredApeYachtClub",'
                    '"owner":"0xd1a770cff075f35fe5efdfc247ad1a5f7a7047a5",'
                    '"symbol":"BAYC",'
                    '"supply":"10000",'
                    '"tokenURI":"ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/1234"' 
                '}'
            '}';

        assertEq((actual), (expected));
    }

    function test_ResolveTwoLabels_InvalidCombinations() public view {
        // Test EOA.EOA case
        bytes[] memory labels = new bytes[](4);
        labels[0] = bytes(VITALIK.toHexString());
        labels[1] = bytes(address(0xdead).toHexString());
        labels[2] = bytes("jsonapi");
        labels[3] = bytes("eth");

        bytes memory name = Encode(labels);
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        string memory actual = this.extractJsonFromResponse(result);
        //forgefmt:disable-next-item
        string memory expected = 
            '{'
                '"ok":false,'
                '"time":"1739434199",'
                '"block":"21836278",'
                '"error":"Token Not Found 0xd8da6bf26964af9d7eed9e03e53415d37aa96045.0x000000000000000000000000000000000000dead.jsonapi.eth",'
                '"data":""'
            '}';
        assertEq(actual, expected);

        // Test token.token case (ERC20.ERC20)
        labels[0] = bytes(WETH.toHexString());
        labels[1] = bytes(USDC.toHexString());
        name = Encode(labels);
        result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        actual = this.extractJsonFromResponse(result);
        //forgefmt:disable-next-item
        expected = 
            '{'
                '"ok":false,'
                '"time":"1739434199",'
                '"block":"21836278",'
                '"error":"Multiple Tokens 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.jsonapi.eth",'
                '"data":""'
            '}';
        assertEq(actual, expected);
    }

    function testRevertOnUnsupportedSelector() public {
        bytes[] memory labels = new bytes[](3);
        labels[0] = bytes("vitalik");
        labels[1] = bytes("jsonapi");
        labels[2] = bytes("eth");

        bytes memory name = Encode(labels);
        vm.expectRevert(Resolver.OnlyContentHashSupported.selector);
        resolver.resolve(name, abi.encodeWithSelector(iResolver.addr.selector, bytes32(0)));
    }

    function testRevertOnTooManyLabels() public {
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

    function testRevertOnNonContenthashRequest() public {
        bytes memory name = hex"07766974616c696b076a736f6e617069036574680000";
        bytes4 addrSelector = 0x3b3b57de;
        bytes32 namehash = 0xd8da6bf26964af9d7eed9e03e53415d37aa96045b8c16e3f4a0f8ca9eabc1e33;
        bytes memory request = abi.encodePacked(addrSelector, namehash);

        vm.expectRevert(abi.encodeWithSignature("OnlyContentHashSupported()"));
        resolver.resolve(name, request);
    }

    function testExactWeb3Request() public view {
        bytes memory name = hex"07766974616c696b076a736f6e617069036574680000";
        bytes32 namehash = keccak256(
            abi.encodePacked(
                keccak256(
                    abi.encodePacked(keccak256(abi.encodePacked(bytes32(0), keccak256("eth"))), keccak256("jsonapi"))
                ),
                keccak256("vitalik")
            )
        );

        bytes memory request = abi.encodeWithSelector(iResolver.contenthash.selector, namehash);
        bytes memory result = resolver.resolve(name, request);
        assertTrue(result.length > 0, "Response should not be empty");
    }

    function test_GetAddrFromLabel() public view {
        // Test registered ticker
        address addr = resolver.getAddrFromLabel(bytes("weth"));
        assertEq(addr, WETH, "Registered ticker should resolve to correct address");

        // Test Ethereum address in hex string format
        addr = resolver.getAddrFromLabel(bytes(VITALIK.toHexString()));
        assertEq(addr, VITALIK, "Should resolve hex address string to address");

        // Test truly non-existent name with random bytes - guaranteed not to resolve
        bytes memory randomLabel = bytes("nonexistent123456789abcdef123456789abcdef123456789");
        addr = resolver.getAddrFromLabel(randomLabel);
        assertEq(addr, address(0), "Truly non-existent name should resolve to zero address");

        // Test empty string
        //addr = resolver.getAddrFromLabel(bytes(""));
        //assertEq(addr, address(0), "Empty string should resolve to zero address");
    }

    function Encode(bytes[] memory _names) public pure returns (bytes memory) {
        uint256 len = _names.length;
        bytes memory _name = abi.encodePacked(bytes1(0));
        unchecked {
            while (len > 0) {
                --len;
                _name = bytes.concat(bytes1(uint8(_names[len].length)), _names[len], _name);
            }
        }
        return _name;
    }
}
