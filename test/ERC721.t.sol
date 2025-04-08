// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/LibJSON.sol";
import "../src/Utils.sol";
import {iERC721} from "../src/interfaces/IERC.sol";
import {LibString} from "solady/utils/LibString.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";

contract ERC721Test is Test {
    using LibJSON for *;
    using Utils for *;
    using LibString for *;

    // Known token addresses for mainnet
    address constant BAYC = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
    address constant VITALIK = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    function setUp() public {}

    function test_GetInfo721() public view {
        // Test with BAYC (real ERC721 token)
        bytes memory info = BAYC.erc721Info();

        string memory expected = string(
            abi.encodePacked(
                '"erc":721,"token":{"contract":"',
                BAYC.toHexStringChecksummed(),
                '","name":"',
                BAYC.getName(),
                '","supply":"',
                BAYC.getTotalSupply721(),
                '","symbol":"',
                BAYC.getSymbol(),
                '"}'
            )
        );

        assertEq(string(info), expected);
    }

    function test_GetUserInfo721() public view {
        // Test with real ERC721 token and user
        bytes memory info = VITALIK.erc721UserInfo(BAYC);
        //forge-fmt:disable-next-line
        string memory expected = string(
            abi.encodePacked(
                '"erc":721,' '"token":{',
                '"contract":"0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",',
                '"name":"BoredApeYachtClub",',
                '"supply":"10000",',
                '"symbol":"BAYC",',
                '"user":{',
                '"address":"0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",',
                '"balance":"1"',
                "}" "}"
            )
        );

        assertEq(string(info), expected);
    }

    function test_GetInfoByTokenId() public view {
        // Test with real BAYC token
        uint256 tokenId = 1234;
        bytes memory info = BAYC.getInfoByTokenId(tokenId);
        //forge-fmt:disable-next-line
        string memory expected = '"erc":721,' '"token":{' '"contract":"0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",'
            '"id":"1234",' '"name":"BoredApeYachtClub",' '"owner":"0xd1a770cff075f35fe5efdfc247ad1a5f7a7047a5",'
            '"symbol":"BAYC",' '"supply":"10000",'
            '"tokenURI":"ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/1234"' "}";
        console.log(expected);

        assertEq(string(info), expected);
    }
}
