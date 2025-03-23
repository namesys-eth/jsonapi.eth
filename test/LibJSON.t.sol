// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/LibJSON.sol";
import "../src/Utils.sol";
import {iERC20, iERC721} from "../src/interfaces/IERC.sol";
import {LibString} from "solady/utils/LibString.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";
import {Brutalizer} from "../lib/solady/test/utils/Brutalizer.sol";

contract LibJSONTest is Test, Brutalizer {
    using LibJSON for *;
    using Utils for *;
    using LibString for *;

    iResolver public nonToken = iResolver(0x226159d592E2b063810a10Ebf6dcbADA94Ed68b8);

    // Known token addresses for mainnet
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ENS_NFT = 0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85;
    address constant BAYC = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;

    function setUp() public {}

    function test_Varint() public pure {
        assertEq(LibJSON.varint(127), hex"7f");

        // Test numbers requiring two bytes
        assertEq(LibJSON.varint(128), hex"8001");
        assertEq(LibJSON.varint(129), hex"8101");
        assertEq(LibJSON.varint(255), hex"ff01");
        assertEq(LibJSON.varint(256), hex"8002");
        assertEq(LibJSON.varint(257), hex"8102");
        assertEq(LibJSON.varint(510), hex"fe03");
        assertEq(LibJSON.varint(511), hex"ff03");
        assertEq(LibJSON.varint(512), hex"8004");
        assertEq(LibJSON.varint(513), hex"8104");
        assertEq(LibJSON.varint(1023), hex"ff07");
        assertEq(LibJSON.varint(1024), hex"8008");
        assertEq(LibJSON.varint(1025), hex"8108");
        // Test max allowed value
        assertEq(LibJSON.varint(32767), hex"ffff");
        //vm.expectRevert(LibJSON.InvalidLength.selector);
        //LibJSON.varint(32768);
    }

    function test_EncodeJSON() public pure {
        // Test normal data
        bytes memory data = "test";
        bytes memory encoded = LibJSON.encodeContentHash(data);
        assertEq(encoded, abi.encode(abi.encodePacked(hex"e30101800400", hex"04", data)));

        // Test large data
        data = new bytes(1000);
        encoded = LibJSON.encodeContentHash(data);
        assertEq(encoded, abi.encode(abi.encodePacked(hex"e30101800400", LibJSON.varint(data.length), data)));
    }

    function test_ToError() public view {
        bytes memory data = "test data";
        bytes memory errorJson = LibJSON.toError("test error", data);
        string memory buffer = string.concat(
            '{"ok":false,"time":"',
            block.timestamp.toString(),
            '","block":"',
            block.number.toString(),
            '","error":"test error","data":"',
            data.toHexString(),
            '"}'
        );
        bytes memory expected = abi.encodePacked(hex"e30101800400", LibJSON.varint(bytes(buffer).length), buffer);
        console.logBytes(errorJson);
        console.logBytes(expected);
        assertEq(abi.decode(errorJson, (bytes)), expected);
    }

    function test_ToError_NoData() public view {
        string memory errMsg = "test error";
        bytes memory errorJson = LibJSON.toError(errMsg);
        string memory buffer = string.concat(
            '{"ok":false,"time":"',
            block.timestamp.toString(),
            '","block":"',
            block.number.toString(),
            '","error":"test error","data":""}'
        );
        bytes memory expected = abi.encodePacked(hex"e30101800400", LibJSON.varint(bytes(buffer).length), buffer);
        console.logBytes(errorJson);
        assertEq(errorJson, abi.encode(expected));
    }

    function test_ToJSON() public view {
        bytes memory data = '{"hello":"world"}';
        bytes memory jsonResult = LibJSON.toJSON(data);

        bytes memory expected = bytes(
            string.concat(
                '{"ok":true,"time":"',
                block.timestamp.toString(),
                '","block":"',
                block.number.toString(),
                '",{"hello":"world"}}'
            )
        );
        expected = abi.encodePacked(hex"e30101800400", LibJSON.varint(expected.length), expected);

        assertEq(jsonResult, abi.encode(expected));
    }

    /*
    function test_GetUserInfo20() public view {
        address testUser = address(0x1234);
        bytes memory info = testUser.erc20UserInfo(iERC20(WETH));
        console.log("TEST USER");
        console.log(string(info));
        // forgefmt: disable-next-item
        string memory expected = 
            '"erc":20,'
            '"token":{'
                '"contract":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",'
                '"decimals":17,'
                '"marketcap":"7911248370.108",'
                '"name":"Wrapped Ether",'
                '"price":"2682.386649",'
                '"supply":"2949331.847",'
                '"symbol":"WETH",'
                '"user":{'
                    '"address":"0x0000000000000000000000000000000000001234",'
                    '"balance":"00"'
                '}'
            '}';
        console.log("USER INFO");
        console.log(string(info));
        console.log("EXPECTED");
        console.log(expected);
        assertEq(string(info), expected);
    }
    */
    function test_GetUserInfo721() public view {
        address testUser = address(0x1234);

        // Test with ENS NFT
        bytes memory info = testUser.erc721UserInfo(ENS_NFT);

        // Use the exact JSON format from logs - updated to match actual order
        // forgefmt: disable-next-item
        string memory expected = 
            '"erc":721,'
                '"token":{'
                    '"contract":"0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85",'
                    '"name":"N/A",'
                    '"supply":"0",'
                    '"symbol":"N/A",'
                    '"user":{'
                    '"address":"0x0000000000000000000000000000000000001234",'
                    '"balance":"0"' 
                '}' 
            '}';

        assertEq(string(info), expected);
    }

    function test_GetInfo20() public view {
        // Test with WETH
        bytes memory info = iERC20(WETH).erc20Info();
        // forgefmt: disable-next-item
        string memory expected = 
            '"erc":20,'
            '"token":{'
                '"contract":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",'
                '"decimals":18,'
                '"marketcap":"7911248370.108695",'
                '"name":"Wrapped Ether",'
                '"price":"2682.386649",'
                '"supply":"2949331.847091",'
                '"symbol":"WETH"'
            '}';
        assertEq(string(info), expected);
    }

    function test_GetInfo721() public view {
        // Test with ENS NFT
        bytes memory info = ENS_NFT.erc721Info();
        // forgefmt: disable-next-item
        string memory expected = 
            '"erc":721,'
            '"token":{'
                '"contract":"0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85",'
                '"name":"N/A",'
                '"supply":"0",'
                '"symbol":"N/A"'
            '}';

        assertEq(string(info), expected);

        info = BAYC.erc721Info();
        // forgefmt: disable-next-item
        expected = 
            '"erc":721,'
            '"token":{'
                '"contract":"0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",'
                '"name":"BoredApeYachtClub",'
                '"supply":"10000",'
                '"symbol":"BAYC"'
            '}';
        assertEq(string(info), expected);
    }

    function test_GetInfoByTokenId() public view {
        // Test with ENS NFT token #1234
        uint256 tokenId = 1234;
        bytes memory info = BAYC.getInfoByTokenId(tokenId);

        // forgefmt: disable-next-item
        string memory expected = 
            '"erc":721,'
            '"token":{'
                '"contract":"0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",'
                '"id":"1234",'
                '"name":"BoredApeYachtClub",'
                '"owner":"0xd1a770cff075f35fe5efdfc247ad1a5f7a7047a5",'
                '"symbol":"BAYC","supply":"10000","tokenURI":"ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/1234"'
            '}';
        console.log(expected);
        assertEq(string(info), expected);
    }

    function varintTester(uint256 length) internal pure returns (bytes memory) {
        return (length < 128)
            ? abi.encodePacked(uint8(length))
            : abi.encodePacked(bin((length % 128) + 128), bin(length / 128));
    }

    function bin(uint256 x) private pure returns (bytes memory b) {
        if (x > 0) return abi.encodePacked(bin(x / 256), bytes1(uint8(x % 256)));
    }

    // Fuzz tests
    function testFuzz_Varint(uint256 value) public pure {
        vm.assume(value > 0 && value < 32768); // Max allowed value
        bytes memory encoded = LibJSON.varint(value);
        bytes memory expected = varintTester(value);
        assertEq(encoded, expected);
    }
}
