// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ERC173.sol";
import {iERC173} from "../src/interfaces/IERC.sol";

contract MockERC173 is ERC173 {}

contract ERC173Test is Test {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    ERC173 public erc173;
    address owner = address(1);
    address newOwner = address(2);

    function setUp() public {
        vm.startPrank(owner);
        erc173 = new MockERC173();
        vm.stopPrank();
    }

    function test_Constructor() public view {
        assertEq(erc173.owner(), owner);
    }

    function test_TransferOwnership() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, newOwner);
        erc173.transferOwnership(newOwner);
        assertEq(erc173.owner(), newOwner);
        vm.stopPrank();
    }

    function test_TransferOwnership_RevertIfNotOwner() public {
        vm.startPrank(address(3));
        vm.expectRevert(ERC173.OnlyOwner.selector);
        erc173.transferOwnership(newOwner);
        vm.stopPrank();
    }
}
