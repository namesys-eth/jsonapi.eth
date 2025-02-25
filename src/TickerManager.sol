// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import {iERC20, iERC721, iERC165} from "./interfaces/IERC.sol";
import {iENS} from "./interfaces/IENS.sol";
import "./ERC165.sol";
import "./Utils.sol";
import "./LibJSON.sol";
import "solady/utils/LibString.sol";
import "solady/utils/LibBytes.sol";

/**
 * @title TickerManager
 * @author WTFPL.ETH
 * @notice Manages token ticker registrations, featured tokens, and metadata caching
 * @dev Inherits from ERC165 for interface support. Index 0 in Featured array is reserved for ETH.
 */
contract TickerManager is ERC165 {
    using Utils for *;
    using LibString for *;
    using LibBytes for bytes;
    using LibJSON for *;

    /**
     * @notice Ticker registration structure
     * @dev Packed to use single storage slot (1+8+20 = 29 bytes)
     * @custom:field _featured Index in Featured array (0 = not featured)
     * @custom:field _erc Token standard (20 = ERC20, 721 = ERC721)
     * @custom:field _addr Token contract address
     */
    struct Ticker {
        uint8 _featured;
        uint16 _erc;
        address _addr;
        string _name;
        string _symbol;
        uint8 _decimals;
    }

    /**
     * @notice Contract constructor
     * @dev Initializes ETH as the first featured token at index 0
     */
    constructor() {
        // Initialize ETH as the first featured token
        bytes32 hash = keccak256(abi.encodePacked(JSONAPIRoot, keccak256("eth")));
        Featured.push(hash);
        Tickers[hash] = Ticker(0, 20, address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), "Ethereum", "ETH", 18);
    }

    /**
     * @dev Maximum number of featured tokens allowed
     */
    uint8 private constant MAX_FEATURED = type(uint8).max;
    /**
     * @dev Standard identifier for ERC20 tokens
     */
    uint16 private constant ERC20_STANDARD = 20;
    /**
     * @dev Standard identifier for ERC721 tokens
     */
    uint16 private constant ERC721_STANDARD = 721;

    /**
     * @dev Maps node hash to token metadata
     */
    mapping(bytes32 => bytes) public TokenInfo;
    /**
     * @dev Maps node hash to ticker registration data
     */
    mapping(bytes32 => Ticker) public Tickers;
    /**
     * @dev Array of featured token node hashes. Index 0 is reserved for ETH
     */
    bytes32[] public Featured;

    /**
     * @dev ENS registry contract address
     */
    //iENS public constant ENS = iENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    /**
     * @dev ENS root node hash
     */
    bytes32 public constant ENSRoot = keccak256(abi.encodePacked(bytes32(0), keccak256("eth")));
    /**
     * @dev JSON API root node hash
     */
    bytes32 public constant JSONAPIRoot = keccak256(abi.encodePacked(ENSRoot, keccak256("jsonapi")));

    /**
     * @notice Emitted when a ticker is added/updated/removed
     * @param _ticker Ticker Symbol / lowercase
     * @param _addr Contract address
     * @param node Ticker node hash
     */
    event TickerAdded(string indexed _ticker, address indexed _addr, bytes32 node);
    event TickerRemoved(bytes32 indexed node);
    /**
     * @notice Emitted when a ticker's featured status changes
     * @param node Ticker node hash
     * @param featured True when featured, false when unfeatured
     */
    event TokenFeatured(bytes32 indexed node, bool featured);

    /**
     * @notice Emitted when token metadata is updated
     * @param node Ticker node hash
     */
    event CacheUpdated(bytes32 indexed node);

    /**
     * @notice Thrown when attempting to register a ticker that already exists
     */
    error DuplicateTicker(bytes32 node);
    /**
     * @notice Thrown when attempting to operate on a non-existent ticker
     */
    error TickerNotFound(bytes32 node);
    /**
     * @notice Thrown when attempting to operate on an invalid featured index
     */
    error InvalidFeaturedIndex();
    /**
     * @notice Thrown when attempting to exceed maximum featured capacity
     */
    error FeaturedCapacityExceeded();
    /**
     * @notice Thrown when attempting to operate on a non-token contract
     */
    error NotTokenContract();
    /**
     * @notice Thrown when input validation fails
     */
    error InvalidInput();

    /**
     * @notice Register or update a token ticker
     * @dev Hashes ticker name with JSONAPIRoot to create node
     * @param featured Whether to add to featured list
     * @param addr Token contract address
     * @param ticker Human-readable ticker symbol (e.g., "DAI")
     */
    function setTicker(bool featured, address addr, string calldata ticker) external onlyOwner {
        if (addr == address(0) || bytes(ticker).length == 0) revert InvalidInput();
        if (addr.code.length == 0) revert NotTokenContract();
        uint16 erc = uint16(addr.getERCType());
        if (erc == 0) revert NotTokenContract();
        bytes32 node = keccak256(abi.encodePacked(JSONAPIRoot, keccak256(bytes(ticker))));
        if (Tickers[node]._addr != address(0)) revert DuplicateTicker(node);

        uint8 fid;
        if (featured) {
            fid = uint8(Featured.length);
            if (fid >= MAX_FEATURED) revert FeaturedCapacityExceeded();
            Featured.push(node);
            emit TokenFeatured(node, true);
        }
        Tickers[node] =
            Ticker(fid, erc, addr, addr.getName(), addr.getSymbol(), erc == 20 ? iERC20(addr).decimals() : 0);
        emit TickerAdded(ticker, addr, node);
    }

    function setTickerBatch(address[] calldata addrs, string[] calldata tickers) external onlyOwner {
        uint256 len = addrs.length;
        if (len == 0 || len != tickers.length) revert InvalidInput();

        for (uint256 i = 0; i < len; i++) {
            address addr = addrs[i];
            if (addr == address(0)) revert InvalidInput();
            string memory ticker = tickers[i];
            if (bytes(ticker).length == 0) revert InvalidInput();

            uint16 erc = uint16(addr.getERCType());
            if (erc == 0) revert NotTokenContract();
            bytes32 node = keccak256(abi.encodePacked(JSONAPIRoot, keccak256(bytes(ticker))));
            if (Tickers[node]._addr != address(0)) revert DuplicateTicker(node);

            Tickers[node] =
                Ticker(0, erc, addr, addr.getName(), addr.getSymbol(), erc == 20 ? iERC20(addr).decimals() : 0);
            emit TickerAdded(ticker, addr, node);
        }
    }

    /**
     * @notice Set multiple featured tickers
     * @dev Adds to end of featured list
     * @param nodes Array of ticker node hashes to feature
     */
    function setFeaturedBatch(bytes32[] calldata nodes) external onlyOwner {
        uint256 len = nodes.length;
        if (len == 0) revert InvalidInput();
        if (Featured.length + len >= MAX_FEATURED) revert FeaturedCapacityExceeded();

        for (uint256 i = 0; i < len; i++) {
            bytes32 node = nodes[i];
            Ticker storage ticker = Tickers[node];
            if (ticker._addr == address(0)) revert TickerNotFound(node);
            if (ticker._featured != 0) revert DuplicateTicker(node);

            uint256 fid = Featured.length;
            ticker._featured = uint8(fid);
            Featured.push(node);
            emit TokenFeatured(node, true);
        }
    }

    /**
     * @notice Remove a registered ticker
     * @dev Handles featured index reorganization
     * @param node Ticker node hash to remove
     */
    function removeTicker(bytes32 node) external onlyOwner {
        Ticker memory ticker = Tickers[node];
        if (ticker._addr == address(0)) revert TickerNotFound(node);

        if (ticker._featured > 0) {
            bytes32 lastNode = Featured[Featured.length - 1];
            Ticker storage lastTicker = Tickers[lastNode];
            if (lastTicker._featured > 0) {
                Featured[ticker._featured] = lastNode;
                lastTicker._featured = ticker._featured;
            }

            Featured.pop();
            emit TokenFeatured(node, false);
        }
        delete Tickers[node];
        emit TickerRemoved(node);
    }

    /**
     * @notice Feature an existing ticker
     * @dev Adds to end of featured list
     * @param node Ticker node hash to feature
     */
    function setFeatured(bytes32 node) external onlyOwner {
        Ticker storage ticker = Tickers[node];
        if (ticker._addr == address(0)) revert TickerNotFound(node);
        if (ticker._featured > 0) revert DuplicateTicker(node);

        uint256 fid = Featured.length;
        if (fid == MAX_FEATURED) revert FeaturedCapacityExceeded();

        ticker._featured = uint8(fid);
        Featured.push(node);
        emit TokenFeatured(node, true);
    }

    /**
     * @notice Remove a ticker from featured list by index
     * @dev Maintains array continuity by swapping with last element
     * @param node Ticker node hash to remove
     */
    function removeFeatured(bytes32 node) external onlyOwner {
        uint8 fid = Tickers[node]._featured;
        if (fid == 0) revert InvalidFeaturedIndex();

        uint256 lastIndex = Featured.length - 1;
        bytes32 lastNode = Featured[lastIndex];

        if (fid != lastIndex) {
            Featured[fid] = lastNode;
            Tickers[lastNode]._featured = fid;
        }

        Featured.pop();
        Tickers[node]._featured = 0;
        emit TokenFeatured(node, false);
    }

    /**
     * @notice Cache additional token metadata
     * @dev Data format depends on token standard:
     *      ERC20: (name, symbol, decimals, img, info)
     *      ERC721: (name, symbol, img, info)
     * @param node Ticker node hash
     * @param data ABI-encoded metadata parameters
     */
    function setCache(bytes32 node, bytes calldata data) external onlyOwner {
        if (Tickers[node]._addr == address(0)) revert TickerNotFound(node);
        TokenInfo[node] = data;
        emit CacheUpdated(node);
    }

    /**
     * @notice Get count of featured tickers
     * @return Current number of featured tokens
     */
    function getFeaturedCount() public view returns (uint256) {
        return Featured.length;
    }

    function getFeatured() public view returns (bytes32[] memory) {
        return Featured;
    }

    function getFeaturedUser(address _owner) public view returns (bytes memory) {
        if (_owner == address(0)) revert InvalidInput();

        // Pre-allocate memory for featured token data
        bytes memory featured20 = LibJSON.getETHFeatured(_owner);
        bytes memory featured721 = LibJSON.getENSFeatured(_owner);

        // Cache array length to save gas
        uint256 len = Featured.length;

        // Skip index 0 (ETH) and process remaining featured tokens
        for (uint256 i = 1; i < len;) {
            Ticker memory ticker = Tickers[Featured[i]];
            uint256 balance = iERC20(ticker._addr).balanceOf(_owner);

            // Only process tokens with non-zero balance
            if (balance > 0) {
                if (ticker._erc == 20) {
                    featured20 = LibJSON.getFeatured20(ticker._decimals, ticker._addr, balance, ticker._symbol).concat(
                        featured20
                    );
                } else if (ticker._erc == 721) {
                    featured721 = LibJSON.getFeatured721(ticker._addr, balance, ticker._symbol).concat(featured721);
                }
            }

            // Gas-efficient increment
            unchecked {
                ++i;
            }
        }

        // Construct final JSON response
        return abi.encodePacked(
            '{"address":"',
            _owner.toHexStringChecksummed(),
            '","name":"',
            _owner.getPrimaryName(),
            '","erc20":{',
            featured20,
            '},"erc721":{',
            featured721,
            "}}"
        );
    }
}
