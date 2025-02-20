// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/LibJSON.sol";
import "../src/Utils.sol";
import {iERC20, iERC721} from "../src/interfaces/IERC.sol";
import {LibString} from "solady/utils/LibString.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";
import "./mocks/NonToken.sol";
import {Brutalizer} from "../lib/solady/test/utils/Brutalizer.sol";

contract LibJSONTest is Test, Brutalizer {
    using LibJSON for *;
    using Utils for *;
    using LibString for *;

    NonToken public nonToken;

    // Known token addresses for mainnet
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ENS_NFT = 0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85;

    function setUp() public {
        // Fork mainnet to have access to real tokens
        vm.createSelectFork("mainnet", 21836278); // Use specific block for consistency
        vm.startPrank(address(this));
        nonToken = new NonToken();
        vm.stopPrank();
    }

    function test_Varint() public {
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
        vm.expectRevert(LibJSON.InvalidLength.selector);
        LibJSON.varint(32768);
    }

    function test_EncodeJSON() public pure {
        // Test normal data
        bytes memory data = "test";
        bytes memory encoded = LibJSON.encodeJSON(data);
        assertEq(encoded, abi.encode(abi.encodePacked(hex"e30101800400", hex"04", data)));

        // Test large data
        data = new bytes(1000);
        encoded = LibJSON.encodeJSON(data);
        assertEq(encoded, abi.encode(abi.encodePacked(hex"e30101800400", LibJSON.varint(data.length), data)));
    }

    function test_ToError() public view {
        string memory errMsg = "test error";
        bytes memory data = "test data";
        bytes memory errorJson = LibJSON.toError(errMsg, data);

        bytes memory expected = abi.encodePacked(
            hex"e30101800400",
            LibJSON.varint(
                bytes(
                    string.concat(
                        '{"ok":false,"time":',
                        block.timestamp.toString(),
                        ',"block":',
                        block.number.toString(),
                        ',"error":"test error","data":"',
                        data.toHexString(),
                        '"}'
                    )
                ).length
            ),
            '{"ok":false,"time":',
            block.timestamp.toString(),
            ',"block":',
            block.number.toString(),
            ',"error":"test error","data":"',
            data.toHexString(),
            '"}'
        );

        assertEq(errorJson, abi.encode(expected));
    }

    function test_ToError_NoData() public view {
        string memory errMsg = "test error";
        bytes memory errorJson = LibJSON.toError(errMsg);

        bytes memory expected = abi.encodePacked(
            hex"e30101800400",
            LibJSON.varint(
                bytes(
                    string.concat(
                        '{"ok":false,"time":',
                        block.timestamp.toString(),
                        ',"block":',
                        block.number.toString(),
                        ',"error":"test error","data":""}'
                    )
                ).length
            ),
            '{"ok":false,"time":',
            block.timestamp.toString(),
            ',"block":',
            block.number.toString(),
            ',"error":"test error","data":""}'
        );

        assertEq(errorJson, abi.encode(expected));
    }

    function test_ToJSON() public view {
        bytes memory data = '{"hello":"world"}';
        bytes memory jsonResult = LibJSON.toJSON(data);

        bytes memory expected = bytes(
            string.concat(
                '{"ok":true,"time":',
                block.timestamp.toString(),
                ',"block":',
                block.number.toString(),
                ',"result":{"hello":"world"}}'
            )
        );
        expected = abi.encodePacked(hex"e30101800400", LibJSON.varint(expected.length), expected);

        assertEq(jsonResult, abi.encode(expected));
    }

    function test_ToText() public view {
        bytes memory data = '{"hello":"world"}';
        string memory textResult = LibJSON.toText(data);

        string memory expected = string(
            abi.encodePacked(
                '{"ok":true,"time":',
                block.timestamp.toString(),
                ',"block":',
                block.number.toString(),
                ',"result":{"hello":"world"}}'
            )
        );

        assertEq(textResult, expected);
    }

    function test_ToTextError() public view {
        string memory errMsg = "test error";
        string memory textResult = LibJSON.toTextError(errMsg);

        string memory expected = string(
            abi.encodePacked(
                '{"ok":false,"time":',
                block.timestamp.toString(),
                ',"block":',
                block.number.toString(),
                ',"error":"test error"}'
            )
        );

        assertEq(textResult, expected);
    }

    function test_GetUserInfo20() public view {
        address testUser = address(0x1234);
        //vm.deal(testUser, 1 ether);

        // Test with WETH
        bytes memory info = LibJSON.getUserInfo20(testUser, WETH);
        (, string memory priceStr) = WETH.getPrice();
        uint8 decimals = WETH.getDecimalsUint();

        string memory expected = string(
            abi.encodePacked(
                '{"address":"',
                testUser.toHexStringChecksummed(),
                '","_balance":"0","balance":"0","contract":"',
                WETH.toHexStringChecksummed(),
                '","decimals":',
                decimals.toString(),
                ',"ens":"","erc":20,"name":"Wrapped Ether","price":"',
                priceStr,
                '","supply":"',
                WETH.getTotalSupply20(decimals, 3),
                '","symbol":"WETH","value":"0"}'
            )
        );

        assertEq(string(info), expected);
    }

    function test_GetUserInfo721() public view {
        address testUser = address(0x1234);

        // Test with ENS NFT
        bytes memory info = LibJSON.getUserInfo721(testUser, ENS_NFT);

        string memory expected = string(
            abi.encodePacked(
                '{"address":"',
                testUser.toHexStringChecksummed(),
                '","balance":"0","contract":"',
                ENS_NFT.toHexStringChecksummed(),
                '","ens":"","erc":721,"name":"N/A","supply":"0","symbol":"N/A"}'
            )
        );

        assertEq(string(info), expected);
    }

    function test_GetInfo20() public view {
        // Test with WETH
        bytes memory info = LibJSON.getInfo20(WETH);
        (, string memory priceStr) = WETH.getPrice();
        uint8 decimals = WETH.getDecimalsUint();

        string memory expected = string(
            abi.encodePacked(
                '{"contract":"',
                WETH.toHexStringChecksummed(),
                '","decimals":',
                decimals.toString(),
                ',"erc":20,"name":"Wrapped Ether","price":"',
                priceStr,
                '","supply":"',
                WETH.getTotalSupply20(decimals, 3),
                '","symbol":"WETH"}'
            )
        );

        assertEq(string(info), expected);
    }

    function test_GetInfo721() public view {
        // Test with ENS NFT
        bytes memory info = LibJSON.getInfo721(ENS_NFT);

        string memory expected = string(
            abi.encodePacked(
                '{"contract":"',
                ENS_NFT.toHexStringChecksummed(),
                '","erc":721,"name":"N/A","supply":"0","symbol":"N/A"}'
            )
        );

        assertEq(string(info), expected);
    }

    function test_GetETHFeatured() public {
        address testUser = address(0x1234);
        vm.deal(testUser, 1 ether);

        bytes memory info = LibJSON.getETHFeatured(testUser);
        (uint256 price,) = WETH.getPrice();

        string memory expected = string(
            abi.encodePacked(
                '"ETH":{"_balance":"1000000000000000000","balance":"1","contract":"N/A","decimals":18,"price":"',
                price.formatDecimal(6, 6),
                '","symbol":"ETH","totalsupply":"N/A","value":"',
                price.formatDecimal(6, 6),
                '"}'
            )
        );

        assertEq(string(info), expected);
    }

    function test_GetENSFeatured() public view {
        address testUser = address(0x1234);

        bytes memory info = LibJSON.getENSFeatured(testUser);

        string memory expected = string(
            abi.encodePacked(
                '"ENS":{"balance":"0","contract":"',
                address(Utils.ENS721).toHexStringChecksummed(),
                '","supply":"N/A","symbol":"ENS"}'
            )
        );

        assertEq(string(info), expected);
    }

    function test_GetFeatured721() public view {
        uint256 balance = 5;

        bytes memory info = LibJSON.getFeatured721(ENS_NFT, balance, "ENS");

        string memory expected = string(
            abi.encodePacked(
                '"ENS":{"balance":"5","contract":"',
                ENS_NFT.toHexStringChecksummed(),
                '","supply":"',
                ENS_NFT.getTotalSupply721(),
                '","symbol":"ENS"},'
            )
        );

        assertEq(string(info), expected);
    }

    function test_GetFeatured20() public view {
        uint256 balance = 1000000; // 1 USDC

        bytes memory info = LibJSON.getFeatured20(6, USDC, balance, "USDC");
        (uint256 price, string memory priceStr) = USDC.getPrice();

        string memory expected = string(
            abi.encodePacked(
                '"USDC":{"_balance":"1000000","balance":"1","contract":"',
                USDC.toHexStringChecksummed(),
                '","decimals":"6","price":"',
                priceStr,
                '","supply":"',
                iERC20(USDC).totalSupply().formatDecimal(6, 3),
                '","symbol":"USDC","value":"',
                balance.calculateUSDCValue(price, 6).formatDecimal(6, 3),
                '"},'
            )
        );

        assertEq(string(info), expected);
    }

    // Test error cases
    function test_GetInfo20_NonToken() public view {
        bytes memory info = LibJSON.getInfo20(address(nonToken));
        string memory expected = string(
            abi.encodePacked(
                '{"contract":"',
                address(nonToken).toHexStringChecksummed(),
                '","decimals":0,"erc":20,"name":"N/A","price":"","supply":"0","symbol":"N/A"}'
            )
        );

        assertEq(string(info), expected);
    }

    function test_GetInfo721_NonToken() public view {
        bytes memory info = LibJSON.getInfo721(address(nonToken));
        string memory expected = string(
            abi.encodePacked(
                '{"contract":"',
                address(nonToken).toHexStringChecksummed(),
                '","erc":721,"name":"N/A","supply":"0","symbol":"N/A"}'
            )
        );

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
        vm.assume(value > 0 && value < 16384); // Max allowed value
        bytes memory encoded = LibJSON.varint(value);
        bytes memory expected = varintTester(value);
        assertEq(encoded, expected);
    }
}
