// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

interface iERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface iERC173 {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() external view returns (address);

    function transferOwnership(address _newOwner) external;
}

interface iENS {
    function resolver(bytes32 node) external view returns (address);

    function owner(bytes32 node) external view returns (address);

    function recordExists(bytes32 node) external view returns (bool);
}

interface iENSIP10 {
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory);
}

interface iResolver {
    function addr(bytes32 node) external view returns (address payable);
    function name(bytes32 node) external view returns (string memory);
    function contenthash(bytes32 node) external view returns (bytes memory);
    function text(bytes32 node, string calldata key) external view returns (string memory);
}

interface iOverloadedResolver {
    function addr(bytes32 node, uint256 chainId) external view returns (bytes memory);
}

interface iERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}

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

interface iERC721Metadata is iERC721 {
    function name() external view returns (string memory _name);
    function symbol() external view returns (string memory _symbol);
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

interface iERC721Enumerable is iERC721 {
    function totalSupply() external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function tokenByIndex(uint256 index) external view returns (uint256);
}

interface iERC721ContractMetadata {
    function contractURI() external view returns (string memory);
}

interface iENSNFT {
    function ownerOf(uint256 id) external view returns (address owner);

    function balanceOf(address owner) external view returns (uint256 balance);
}

interface iENSReverse {
    function node(address) external view returns (bytes32);
    function resolver(bytes32) external view returns (address);
    //function name(bytes32) external view returns (string memory);
}

/// @notice Interface for CheckTheChainEthereum contract
interface iCheckTheChainEthereum {
    /// @dev Token struct used in assets mapping
    struct Token {
        string name;
        string symbol;
        uint8 decimals;
    }

    /// @dev Events
    event Registered(address indexed token);
    event OwnershipTransferred(address indexed from, address indexed to);

    /// @dev View functions
    function owner() external view returns (address);
    function assets(address asset) external view returns (Token memory);
    function addresses(string memory symbol) external view returns (address);
    function registered(uint256) external view returns (address);

    /// @dev Main functions
    //function register(address token) external;
    //function getRegistered() external view returns (address[] memory tokens);

    /// @dev Price check functions
    function checkPrice(string calldata token) external view returns (uint256 price, string memory priceStr);
    function checkPrice(address token) external view returns (uint256 price, string memory priceStr);
    function checkPriceInETH(string calldata token) external view returns (uint256 price, string memory priceStr);
    function checkPriceInETH(address token) external view returns (uint256 price, string memory priceStr);
    function checkPriceInETHToUSDC(string calldata token)
        external
        view
        returns (uint256 price, string memory priceStr);
    function checkPriceInETHToUSDC(address token) external view returns (uint256 price, string memory priceStr);

    /// @dev Batch price check functions
    function batchCheckPrices(address[] calldata tokens)
        external
        view
        returns (uint256[] memory prices, string[] memory priceStrs);
    function batchCheckPricesInETH(address[] calldata tokens)
        external
        view
        returns (uint256[] memory prices, string[] memory priceStrs);
    function batchCheckPricesInETHToUSDC(address[] calldata tokens)
        external
        view
        returns (uint256[] memory prices, string[] memory priceStrs);

    /// @dev Token info functions
    function balanceOf(address user, address token) external view returns (uint256 balance, string memory balanceStr);
    function totalSupply(address token) external view returns (uint256 supply, string memory supplyStr);

    /// @dev ENS functions
    function whatIsTheAddressOf(string calldata name)
        external
        view
        returns (address _owner, address receiver, bytes32 node);
    function whatIsTheNameOf(address user) external view returns (string memory);

    /// @dev Admin functions
    function transferOwnership(address to) external payable;

    /// @dev Custom errors
    error Unauthorized();
    error TotalSupplyQueryFailed();
    error InvalidReceiver();
}
