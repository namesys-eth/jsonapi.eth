// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/LibJSON.sol";
import "../src/Utils.sol";
import "../src/Interface.sol";
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
    address constant CTC = 0x0000000000cDC1F8d393415455E382c30FBc0a84;

    function setUp() public {
        // Fork mainnet to have access to real tokens
        vm.createSelectFork("mainnet", 21836278); // Use specific block for consistency
        vm.startPrank(address(this));
        nonToken = new NonToken();
        vm.stopPrank();
    }

    // Test varint encoding
    function test_Varint() public pure {
        assertEq(LibJSON.varint(0), hex"00");
        assertEq(LibJSON.varint(127), hex"7f");
        assertEq(LibJSON.varint(128), hex"8001");
        assertEq(LibJSON.varint(255), hex"ff01");
    }

    // Test JSON encoding
    function test_EncodeJSON() public pure {
        bytes memory data = "test";
        bytes memory encoded = LibJSON.encodeJSON(data);
        assertEq(encoded, abi.encodePacked(hex"e30101800400", hex"04", data));
    }

    // Test error JSON formatting
    function test_ToError() public {
        string memory errMsg = "test error";
        bytes memory data = "test data";
        bytes memory errorJson = LibJSON.toError(errMsg, data);

        // First get the actual output for debugging

        // Create expected output by concatenating the parts
        bytes memory expected = abi.encodePacked(
            hex"e30101800400", // Fixed prefix
            hex"62", // Length of JSON
            "{", // Opening brace {
            '"ok":false,"time":',
            block.timestamp.toString(),
            ',"block":',
            block.number.toString(),
            ',"error":"test error","data":"',
            data.toHexString(),
            '"}'
        );

        assertEq(errorJson, expected);
    }

    // Test error JSON formatting without data
    function test_ToError_NoData() public {
        string memory errMsg = "test error";
        bytes memory errorJson = LibJSON.toError(errMsg);

        // First get the actual output for debugging

        // Create expected output by concatenating the parts
        bytes memory expected = abi.encodePacked(
            hex"e30101800400", // Fixed prefix
            hex"4e", // Length of JSON
            hex"7b", // Opening brace {
            '"ok":false,"time":',
            block.timestamp.toString(),
            ',"block":',
            block.number.toString(),
            ',"error":"test error","data":""}'
        );

        assertEq(errorJson, expected);
    }

    // Test success JSON formatting
    function test_ToJSON() public {
        bytes memory data = "test data";
        bytes memory jsonResult = LibJSON.toJSON(data);

        // First get the actual output for debugging

        // Create expected output by concatenating the parts
        bytes memory expected = abi.encodePacked(
            hex"e30101800400", // Fixed prefix
            hex"43", // Length of JSON
            hex"7b", // Opening brace {
            '"ok":true,"time":',
            block.timestamp.toString(),
            ',"block":',
            block.number.toString(),
            ',"result":{test data}}'
        );

        assertEq(jsonResult, expected);
    }

    // Test ERC20 info formatting
    function test_GetInfo20() public {
        (, string memory priceStr) = Utils.getPrice(WETH);
        bytes memory info = LibJSON.getInfo20(WETH);
        string memory expected = string(
            abi.encodePacked(
                '"contract":"',
                WETH.toHexStringChecksummed(),
                '","decimals":18,"erc":20,"name":"Wrapped Ether","price":"',
                priceStr,
                '","supply":"',
                WETH.getTotalSupply20(18, 3),
                '","symbol":"WETH"'
            )
        );

        assertEq(string(info), expected);
    }

    // Test ERC721 info formatting
    function test_GetInfo721() public {
        string memory expected = string.concat(
            '"contract":"',
            LibString.toHexStringChecksummed(address(ENS_NFT)),
            '",',
            '"erc":721,',
            '"name":"N/A",',
            '"supply":"0",',
            '"symbol":"N/A"'
        );
        bytes memory info = LibJSON.getInfo721(address(ENS_NFT));
        assertEq(string(info), expected);
    }

    // Test ETH featured info
    function test_GetETHFeatured() public {
        address testAccount = address(0x1);
        vm.deal(testAccount, 1 ether);

        bytes memory result = LibJSON.getETHFeatured(testAccount);
        (uint256 price,) = Utils.getPrice(WETH);
        string memory priceStr = Utils.formatDecimal(price, 6, 3);
        string memory expected = string(
            abi.encodePacked(
                '"ETH":{"_balance":"1000000000000000000","balance":"1","contract":"","decimals":"18","price":"',
                priceStr,
                '","symbol":"ETH","totalsupply":"","value":"',
                priceStr,
                '"}'
            )
        );

        assertEq(string(result), expected);
    }

    // Test ETH featured info with zero balance
    function test_GetETHFeatured_ZeroBalance() public {
        address testAccount = address(1);
        vm.deal(testAccount, 0);

        bytes memory result = LibJSON.getETHFeatured(testAccount);
        (uint256 price,) = Utils.getPrice(WETH);
        string memory priceStr = Utils.formatDecimal(price, 6, 3);
        string memory expected = string(
            abi.encodePacked(
                '"ETH":{"_balance":"0","balance":"0","contract":"","decimals":"18","price":"',
                priceStr,
                '","symbol":"ETH","totalsupply":"","value":"0"}'
            )
        );

        assertEq(string(result), expected);
    }

    // Test ENS featured info with Vitalik's address (has ENS names)
    function test_GetENSFeatured() public {
        address testAccount = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        uint256 balance = Utils.ENS721.balanceOf(testAccount);
        // Get the node and resolver
        bytes32 node = Utils.ENSReverse.node(testAccount);
        bytes memory featured = LibJSON.getENSFeatured(testAccount);
        string memory expected = string(
            abi.encodePacked(
                '"ENS":{"balance":"',
                balance.toString(),
                '","contract":"',
                testAccount.toHexStringChecksummed(),
                '","primary":"vitalik.eth"}'
            )
        );

        assertEq(string(featured), expected);
    }

    // Test ENS featured info with zero balance address
    function test_GetENSFeatured_ZeroBalance() public {
        address testAccount = address(0x1111);
        uint256 balance = Utils.ENS721.balanceOf(testAccount);
        assertEq(balance, 0, "Test account should have zero ENS balance");

        bytes memory featured = LibJSON.getENSFeatured(testAccount);

        string memory expected = string(
            abi.encodePacked(
                '"ENS":{"balance":"0","contract":"', testAccount.toHexStringChecksummed(), '","primary":""}'
            )
        );

        assertEq(string(featured), expected);
    }

    // Test ENS featured info with contract address (should have no primary name)
    function test_GetENSFeatured_ContractAddress() public {
        address testAccount = USDC; // Using USDC contract as test case
        uint256 balance = Utils.ENS721.balanceOf(testAccount);

        bytes memory featured = LibJSON.getENSFeatured(testAccount);

        string memory expected = string(
            abi.encodePacked(
                '"ENS":{"balance":"',
                balance.toString(),
                '","contract":"',
                testAccount.toHexStringChecksummed(),
                '","primary":""}'
            )
        );

        assertEq(string(featured), expected);
    }

    // Test ERC721 featured info with balance
    function test_GetFeatured721_WithBalance() public {
        bytes memory featured = LibJSON.getFeatured721(ENS_NFT, 1, "ENS");

        string memory expected = string(
            abi.encodePacked(
                '"ENS":{"balance":"1","contract":"',
                ENS_NFT.toHexStringChecksummed(),
                '","symbol":"ENS","supply":"',
                ENS_NFT.getTotalSupply721(),
                '","metadata":""},'
            )
        );

        assertEq(string(featured), expected);
    }

    // Test ERC721 featured info with zero balance
    function test_GetFeatured721_ZeroBalance() public {
        bytes memory featured = LibJSON.getFeatured721(ENS_NFT, 0, "ENS");

        string memory expected = string(
            abi.encodePacked(
                '"ENS":{"balance":"0","contract":"',
                ENS_NFT.toHexStringChecksummed(),
                '","symbol":"ENS","supply":"',
                ENS_NFT.getTotalSupply721(),
                '","metadata":""},'
            )
        );

        assertEq(string(featured), expected);
    }

    // Test ERC721 featured info with large balance
    function test_GetFeatured721_LargeBalance() public {
        bytes memory featured = LibJSON.getFeatured721(ENS_NFT, 1000, "ENS");

        string memory expected = string(
            abi.encodePacked(
                '"ENS":{"balance":"1000","contract":"',
                ENS_NFT.toHexStringChecksummed(),
                '","symbol":"ENS","supply":"',
                ENS_NFT.getTotalSupply721(),
                '","metadata":""},'
            )
        );

        assertEq(string(featured), expected);
    }

    // Test ERC721 featured info with non-token contract
    function test_GetFeatured721_NonToken() public {
        bytes memory featured = LibJSON.getFeatured721(address(nonToken), 1, "TEST");

        string memory expected = string(
            abi.encodePacked(
                '"TEST":{"balance":"1","contract":"',
                address(nonToken).toHexStringChecksummed(),
                '","symbol":"TEST","supply":"0","metadata":""},'
            )
        );

        assertEq(string(featured), expected);
    }

    // Test ERC20 featured info with balance
    function test_GetFeatured20_WithBalance() public {
        uint256 balance = 1000000; // 1 USDC
        (uint256 price, string memory priceStr) = Utils.getPrice(USDC);
        bytes memory featured = LibJSON.getFeatured20(6, USDC, balance, "USDC");

        string memory expected = string(
            abi.encodePacked(
                '"USDC":{"_balance":"1000000","balance":"1","contract":"',
                USDC.toHexStringChecksummed(),
                '","decimals":"6","price":"',
                priceStr,
                '","supply":"',
                iERC20(USDC).totalSupply().formatDecimal(6, 3),
                '","symbol":"USDC","value":"',
                Utils.calculateUSDCValue(balance, price, 6).formatDecimal(6, 3),
                '"},'
            )
        );

        assertEq(string(featured), expected);
    }

    // Test ERC20 featured info with large balance
    function test_GetFeatured20_LargeBalance() public {
        uint256 balance = 1000000000000; // 1M USDC
        (uint256 price, string memory priceStr) = Utils.getPrice(USDC);
        bytes memory featured = LibJSON.getFeatured20(6, USDC, balance, "USDC");

        string memory expected = string(
            abi.encodePacked(
                '"USDC":{"_balance":"1000000000000","balance":"1000000","contract":"',
                USDC.toHexStringChecksummed(),
                '","decimals":"6","price":"',
                priceStr,
                '","supply":"',
                iERC20(USDC).totalSupply().formatDecimal(6, 3),
                '","symbol":"USDC","value":"',
                Utils.formatDecimal(balance * price / 1e6, 6, 3),
                '"},'
            )
        );

        assertEq(string(featured), expected);
    }

    // Test user info for ERC20
    function test_GetUserInfo20() public {
        (uint256 price, string memory priceStr) = Utils.getPrice(USDC);
        bytes memory info = LibJSON.getUserInfo20(address(this), USDC);
        string memory expected = string(
            abi.encodePacked(
                '"balance":"0","contract":"',
                USDC.toHexStringChecksummed(),
                '","erc":20,"name":"USD Coin","price":"',
                priceStr,
                '","value":"0","supply":"',
                USDC.getTotalSupply20(6, 3),
                '"'
            )
        );

        assertEq(string(info), expected);
    }

    // Test user info for ERC721
    function test_GetUserInfo721() public {
        bytes memory info = LibJSON.getUserInfo721(address(this), ENS_NFT);
        string memory expected = '"balance":"0"';

        assertEq(string(info), expected);
    }

    // Fuzz test varint encoding
    function testFuzz_Varint(uint256 value) public pure {
        value = bound(value, 0, 127); // Limit to valid varint range
        bytes memory encoded = LibJSON.varint(value);
        if (value < 128) {
            assertEq(encoded.length, 1);
            assertEq(uint8(encoded[0]), value);
        } else {
            assertEq(encoded.length, 2);
            assertEq(uint8(encoded[0]) & 0x7f, value % 128);
            assertEq(uint8(encoded[1]), value / 128);
        }
    }

    // Test error cases
    function test_GetInfo20_NonToken() public {
        bytes memory info = LibJSON.getInfo20(address(nonToken));
        string memory expected =
            '"contract":"0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f","decimals":0,"erc":20,"name":"N/A","price":"","supply":"0","symbol":"N/A"';

        assertEq(string(info), expected);
    }

    function test_GetInfo721_NonToken() public {
        bytes memory info = LibJSON.getInfo721(address(nonToken));

        string memory expected = string(
            abi.encodePacked(
                '"contract":"',
                address(nonToken).toHexStringChecksummed(),
                '","erc":721,"name":"N/A","supply":"0","symbol":"N/A"'
            )
        );

        assertEq(string(info), expected);
    }
}
