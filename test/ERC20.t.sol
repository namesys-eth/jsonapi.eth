// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/LibJSON.sol";
import "../src/Utils.sol";
import {iERC20} from "../src/interfaces/IERC.sol";
import {LibString} from "solady/utils/LibString.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";

contract ERC20Test is Test {
    using LibJSON for *;
    using Utils for *;
    using LibString for *;

    // Known token addresses for mainnet
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant VITALIK = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    function setUp() public {}

    function test_GetInfo20() public view {
        bytes memory info = iERC20(WETH).erc20Info();

        //forgefmt:disable-next-item
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

    function test_GetUserInfo20() public view {
        bytes memory info = VITALIK.erc20UserInfo(iERC20(WETH));
        //forgefmt:disable-next-item
        string memory expected = 
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
                '}';

        assertEq(string(info), expected);
    }
}
