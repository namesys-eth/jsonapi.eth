// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

/**
 * @title CheckTheChainEthereum Interface
 * @notice Interface for the CheckTheChainEthereum contract
 * @dev Provides price checking and token information functionality
 */
interface iCheckTheChainEthereum {
    /// @notice Token struct used in assets mapping
    struct Token {
        string name;
        string symbol;
        uint8 decimals;
    }

    /// @notice Events
    event Registered(address indexed token);
    event OwnershipTransferred(address indexed from, address indexed to);

    /// @notice View functions
    function owner() external view returns (address);
    function assets(address asset) external view returns (Token memory);
    function addresses(string memory symbol) external view returns (address);
    function registered(uint256) external view returns (address);

    /// @notice Price check functions
    function checkPrice(string calldata token) external view returns (uint256 price, string memory priceStr);
    function checkPrice(address token) external view returns (uint256 price, string memory priceStr);
    function checkPriceInETH(string calldata token) external view returns (uint256 price, string memory priceStr);
    function checkPriceInETH(address token) external view returns (uint256 price, string memory priceStr);
    function checkPriceInETHToUSDC(string calldata token)
        external
        view
        returns (uint256 price, string memory priceStr);
    function checkPriceInETHToUSDC(address token) external view returns (uint256 price, string memory priceStr);

    /// @notice Batch price check functions
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

    /// @notice Token info functions
    function balanceOf(address user, address token) external view returns (uint256 balance, string memory balanceStr);
    function totalSupply(address token) external view returns (uint256 supply, string memory supplyStr);

    /// @notice ENS functions
    function whatIsTheAddressOf(string calldata name)
        external
        view
        returns (address _owner, address receiver, bytes32 node);
    function whatIsTheNameOf(address user) external view returns (string memory);

    /// @notice Admin functions
    function transferOwnership(address to) external payable;

    /// @notice Custom errors
    error Unauthorized();
    error TotalSupplyQueryFailed();
    error InvalidReceiver();
}
