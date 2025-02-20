// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ERC165.sol";
import {iERC165, iERC721} from "../src/interfaces/IERC.sol";

contract MockERC165 is ERC165 {}

contract ERC165Test is Test {
    MockERC165 public erc165;

    function setUp() public {
        erc165 = new MockERC165();
    }

    function test_SupportsInterface() public view {
        assertTrue(erc165.supportsInterface(type(iERC165).interfaceId));
        assertFalse(erc165.supportsInterface(0xffffffff));
    }

    function test_setInterface() public {
        assertFalse(erc165.supportsInterface(type(iERC721).interfaceId));
        erc165.setInterface(type(iERC721).interfaceId, true);
        assertTrue(erc165.supportsInterface(type(iERC721).interfaceId));
        erc165.setInterface(type(iERC721).interfaceId, false);
        assertFalse(erc165.supportsInterface(type(iERC721).interfaceId));
    }
    /* no need to fool proof dev/owner
    function test_setInterface_Revert() public {
        vm.expectRevert(ERC165.BadInterface.selector);
        erc165.setInterface(0xffffffff, true);
    }
    */
}
