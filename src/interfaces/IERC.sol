// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

/**
 * @title ERC165 Interface
 * @notice Standard interface for ERC165 interface detection
 */
interface iERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * @title ERC173 Interface
 * @notice Standard interface for contract ownership
 */
interface iERC173 {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() external view returns (address);
    function transferOwnership(address _newOwner) external;
}

/**
 * @title ERC20 Interface
 * @notice Standard interface for fungible tokens
 */
interface iERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title ERC721 Interface
 * @notice Standard interface for non-fungible tokens
 */
interface iERC721 is iERC165 {
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata data) external payable;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function approve(address _approved, uint256 _tokenId) external payable;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

/**
 * @title ERC721 Metadata Interface
 * @notice Extension interface for ERC721 token metadata
 */
interface iERC721Metadata is iERC721 {
    function name() external view returns (string memory _name);
    function symbol() external view returns (string memory _symbol);
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

/**
 * @title ERC721 Enumerable Interface
 * @notice Extension interface for enumerable ERC721 tokens
 */
interface iERC721Enumerable is iERC721 {
    function totalSupply() external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function tokenByIndex(uint256 index) external view returns (uint256);
}

/**
 * @title ERC721 Contract Metadata Interface
 * @notice Extension interface for ERC721 contract-level metadata
 */
interface iERC721ContractMetadata {
    function contractURI() external view returns (string memory);
}
