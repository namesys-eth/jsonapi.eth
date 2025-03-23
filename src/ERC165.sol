// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

/**
 * @title ERC165
 * @notice Implementation of ERC-165 interface detection standard
 * @dev Provides interface detection and registration functionality
 */
import {iERC165, iERC173} from "./interfaces/IERC.sol";
import {ERC173} from "./ERC173.sol";

abstract contract ERC165 is iERC165, ERC173 {
    mapping(bytes4 => bool) public supportsInterface;

    event InterfaceUpdated(bytes4 _sig, bool _set);

    /**
     * @notice Initialize with ERC165 and ERC173 interface support
     */
    constructor() {
        supportsInterface[iERC165.supportsInterface.selector] = true;
        supportsInterface[iERC173.owner.selector] = true;
        supportsInterface[type(iERC173).interfaceId] = true;
    }

    /**
     * Sets support for an interface
     * @param _sig Interface signature (function selector)
     * @param _set Boolean indicating whether interface is supported
     */
    function setInterface(bytes4 _sig, bool _set) external onlyOwner {
        supportsInterface[_sig] = _set;
        emit InterfaceUpdated(_sig, _set);
    }
}
