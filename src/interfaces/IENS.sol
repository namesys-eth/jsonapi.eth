// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

/**
 * @title ENS Registry Interface
 * @notice Core interface for the Ethereum Name Service registry
 */
interface iENS {
    function resolver(bytes32 node) external view returns (address);
    function owner(bytes32 node) external view returns (address);
    function recordExists(bytes32 node) external view returns (bool);
}

/**
 * @title ENS ENSIP-10 Interface
 * @notice Interface for the ENSIP-10 wildcard resolution specification
 */
interface iENSIP10 {
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory);
}

/**
 * @title ENS Resolver Interface
 * @notice Standard interface for ENS resolvers
 */
interface iResolver {
    function addr(bytes32 node) external view returns (address payable);
    function name(bytes32 node) external view returns (string memory);
    function contenthash(bytes32 node) external view returns (bytes memory);
    function text(bytes32 node, string calldata key) external view returns (string memory);
}

/**
 * @title ENS Overloaded Resolver Interface
 * @notice Interface for resolvers supporting chain-specific address resolution
 */
interface iOverloadedResolver {
    function addr(bytes32 node, uint256 chainId) external view returns (bytes memory);
}

/**
 * @title ENS NFT Interface
 * @notice Interface for ENS name NFTs
 */
interface iENSNFT {
    function ownerOf(uint256 id) external view returns (address owner);
    function balanceOf(address owner) external view returns (uint256 balance);
}

/**
 * @title ENS Reverse Resolution Interface
 * @notice Interface for ENS reverse resolution
 */
interface iENSReverse {
    function node(address) external view returns (bytes32);
    function resolver(bytes32) external view returns (address);
}
