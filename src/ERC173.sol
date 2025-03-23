// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

/**
 * @title ERC173
 * @notice Implementation of ERC-173 contract ownership standard
 * @dev Basic ownership management with transfer capability
 */
import {iERC173} from "./interfaces/IERC.sol";

abstract contract ERC173 is iERC173 {
    address public owner;

    /**
     * @notice Thrown when a function restricted to the owner is called by another account
     */
    error OnlyOwner();

    /**
     * @notice Sets contract deployer as initial owner
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Restricts function access to the contract owner
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    /**
     * @notice Transfers ownership of the contract to a new address
     * @param _newOwner Address of the new owner
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}
