// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

import "./IERC.sol";
/**
 * Title: ENS Interface Definitions
 * Author: WTFPL.ETH
 * Description: Standard interfaces for Ethereum Name Service
 *
 * This file contains interface definitions for various ENS components used in the system.
 * It includes interfaces for the ENS registry, resolvers, and related functionality.
 */

/**
 * Interface: iENS
 * Core interface for the Ethereum Name Service registry
 */
interface iENS {
    function resolver(bytes32 node) external view returns (address);
    function owner(bytes32 node) external view returns (address);
    function recordExists(bytes32 node) external view returns (bool);
}

/**
 * Interface: iENSIP10
 * Interface for the ENSIP-10 wildcard resolution specification
 */
interface iENSIP10 is iERC165 {
    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory);
}

/**
 * Interface: iResolver
 * Standard interface for ENS resolvers
 */
interface iResolver is iERC165 {
    function addr(bytes32 node) external view returns (address payable);
    function name(bytes32 node) external view returns (string memory);
    function contenthash(bytes32 node) external view returns (bytes memory);
    function text(bytes32 node, string calldata key) external view returns (string memory);
}

/**
 * Interface: iOverloadedResolver
 * Interface for resolvers supporting chain-specific address resolution
 */
interface iOverloadedResolver is iERC165 {
    function addr(bytes32 node, uint256 chainId) external view returns (bytes memory);
}

/**
 * Interface: iENSNFT
 * Interface for ENS name NFTs
 */
interface iENSNFT {
    function ownerOf(uint256 id) external view returns (address owner);
    function balanceOf(address owner) external view returns (uint256 balance);
}

/**
 * Interface: iENSReverse
 * Interface for ENS reverse resolution
 */
interface iENSReverse {
    function node(address) external view returns (bytes32);
    function resolver(bytes32) external view returns (address);
}
