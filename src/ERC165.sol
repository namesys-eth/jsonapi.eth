// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import {iERC165, iERC173} from "./Interface.sol";
import {ERC173} from "./ERC173.sol";

abstract contract ERC165 is iERC165, ERC173 {
    mapping(bytes4 => bool) public supportsInterface;

    event InterfaceUpdated(bytes4 _sig, bool _set);

    constructor() {
        supportsInterface[iERC165.supportsInterface.selector] = true;
        supportsInterface[iERC173.owner.selector] = true;
        supportsInterface[iERC173.transferOwnership.selector] = true;
    }

    //error BadInterface();

    function setInterface(bytes4 _sig, bool _set) external onlyOwner {
        //require(_sig != 0xffffffff, BadInterface());
        supportsInterface[_sig] = _set;
        emit InterfaceUpdated(_sig, _set);
    }
}
