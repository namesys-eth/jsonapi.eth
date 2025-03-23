// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

/**
 * Title: TickerManager
 * Author: namesys.eth
 * Description: Manages token ticker registrations and metadata caching
 */
import {iERC20, iERC721, iERC165} from "./interfaces/IERC.sol";
import {iENS} from "./interfaces/IENS.sol";
import "./ERC165.sol";
import "./Utils.sol";
import "./LibJSON.sol";
import "solady/utils/LibString.sol";
import "solady/utils/LibBytes.sol";

contract TickerManager is ERC165 {
    using Utils for *;
    using LibString for *;
    using LibBytes for bytes;
    using LibJSON for *;

    /**
     * Maps node hash to token contract address
     */
    mapping(bytes32 => address) public Tickers;

    /**
     * ENS root node
     */
    bytes32 public constant ENSRoot = keccak256(abi.encodePacked(bytes32(0), keccak256("eth")));

    /**
     * JSON API node hash
     */
    bytes32 public constant JSONAPIRoot = keccak256(abi.encodePacked(ENSRoot, keccak256("jsonapi")));

    event TickerUpdated(bytes32 indexed node, address indexed addr, uint256 erc);

    /**
     * Thrown when attempting to register a ticker that already exists
     */
    error DuplicateTicker(bytes32 node);

    /**
     * Thrown when attempting to operate on a non-existent ticker
     */
    error TickerNotFound(bytes32 node);

    /**
     * Thrown when attempting to operate on a non-token contract
     */
    error NotTokenContract();

    /**
     * Thrown when input validation fails
     */
    error InvalidInput();

    /**
     * Constructor: TickerManager
     * Initializes ETH as the first token
     */
    constructor() {
        bytes32 hash = keccak256(abi.encodePacked(JSONAPIRoot, keccak256("eth")));
        Tickers[hash] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    }

    /**
     * Function: setTicker
     * Register or update a token ticker
     * Hashes ticker name with JSONAPIRoot to create node
     * @param addr Token contract address
     * @param _hash Hashed ticker name
     */
    function setTicker(address addr, bytes32 _hash) external onlyOwner {
        uint256 erc = addr.getERCType();
        if (erc == 0) revert NotTokenContract();
        bytes32 node = keccak256(abi.encodePacked(JSONAPIRoot, _hash));
        if (Tickers[node] != address(0)) revert DuplicateTicker(node);

        Tickers[node] = addr;
        emit TickerUpdated(node, addr, erc);
    }

    /**
     * Function: setTickerBatch
     * Register or update a batch of token tickers
     * @param _addrs Token contract addresses
     * @param labelhash Hashed ticker names
     */
    function setTickerBatch(address[] calldata _addrs, bytes32[] calldata labelhash) external onlyOwner {
        uint256 len = _addrs.length;
        if (len != labelhash.length) revert InvalidInput();

        for (uint256 i = 0; i < len; i++) {
            uint16 erc = uint16(_addrs[i].getERCType());
            if (erc == 0) revert NotTokenContract();
            bytes32 node = keccak256(abi.encodePacked(JSONAPIRoot, labelhash[i]));
            if (Tickers[node] != address(0)) revert DuplicateTicker(node);

            Tickers[node] = _addrs[i];
            emit TickerUpdated(node, _addrs[i], erc);
        }
    }

    /**
     * Function: removeTicker
     * Remove a registered ticker
     * @param node Ticker node hash to remove
     */
    function removeTicker(bytes32 node) external onlyOwner {
        if (Tickers[node] == address(0)) revert TickerNotFound(node);
        delete Tickers[node];
        emit TickerUpdated(node, address(0), 0);
    }

    /**
     * Function: updateTicker
     * Update an existing ticker to point to a new address
     * @param node Ticker node hash to update
     * @param addr New token contract address
     */
    function updateTicker(bytes32 node, address addr) external onlyOwner {
        uint256 erc = addr.getERCType();
        Tickers[node] = addr;
        emit TickerUpdated(node, addr, erc);
    }
}
