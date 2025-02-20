// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

import {iERC173} from "./interfaces/IERC.sol";

abstract contract ERC173 is iERC173 {
    address public owner;

    error OnlyOwner();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, OnlyOwner());
        _;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}
