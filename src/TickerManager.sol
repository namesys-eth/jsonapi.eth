// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import "./Interface.sol";
import "./ERC165.sol";
import "./Utils.sol";
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
        bytes32 hash = keccak256(abi.encodePacked(JSONAPIRoot, keccak256("eth")));
        Featured.push(hash);
        Tickers[hash] = Ticker(0, 20, address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), "Ethereum", "ETH", 18);
        /*
        hash = keccak256(abi.encodePacked(JSONAPIRoot, keccak256("usdc")));
        Featured.push(hash);
        Tickers[hash] = Ticker(
            0,
            20,
            address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
            "USD Coin",
            "USDC",
            6
        );
        hash = keccak256(abi.encodePacked(JSONAPIRoot, keccak256("weth")));
        Featured.push(hash);
        Tickers[hash] = Ticker(
            0,
            20,
            address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2),
            "Wrapped Ether",
            "WETH",
            18
        );
        hash = keccak256(abi.encodePacked(JSONAPIRoot, keccak256("usdt")));
        Featured.push(hash);
        Tickers[hash] = Ticker(
            0,
            20,
            address(0xdAC17F958D2ee523a2206206994597C13D831ec7),
            "Tether",
            "USDT",
            6
        );*/
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
     * @notice Register or update a token ticker
     * @dev Hashes ticker name with JSONAPIRoot to create node
     * @param featured Whether to add to featured list
     * @param addr Token contract address
     * @param ticker Human-readable ticker symbol (e.g., "DAI")
     */
    function setTicker(bool featured, address addr, string calldata ticker) external onlyOwner {
        require(addr.code.length > 0, NotTokenContract());
        uint16 erc = uint16(addr.getERCType());
        require(erc != 0, NotTokenContract());
        bytes32 node = keccak256(abi.encodePacked(JSONAPIRoot, keccak256(bytes(ticker))));
        require(Tickers[node]._addr == address(0), DuplicateTicker(node));

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
        for (uint256 i = 0; i < addrs.length; i++) {
            address addr = addrs[i];
            string memory ticker = tickers[i];
            uint16 erc = uint16(addr.getERCType());
            require(erc != 0, NotTokenContract());
            bytes32 node = keccak256(abi.encodePacked(JSONAPIRoot, keccak256(bytes(ticker))));
            require(Tickers[node]._addr == address(0), DuplicateTicker(node));
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
        for (uint256 i = 0; i < nodes.length; i++) {
            bytes32 node = nodes[i];

            Ticker storage ticker = Tickers[node];
            require(ticker._addr != address(0), TickerNotFound(node));
            require(ticker._featured == 0, DuplicateTicker(node));
            uint256 fid = Featured.length;
            require(fid < MAX_FEATURED, FeaturedCapacityExceeded());
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
        require(ticker._addr != address(0), TickerNotFound(node));
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

        // Check if ticker is already in Featured array
        if (ticker._featured > 0) revert DuplicateTicker(node);

        uint256 fid = Featured.length;
        if (fid >= MAX_FEATURED) revert FeaturedCapacityExceeded();

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
        require(fid > 0, InvalidFeaturedIndex());

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
        Ticker memory _ticker = Tickers[node];
        require(_ticker._addr != address(0), TickerNotFound(node));
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

    function getFeaturedBalance(address _owner) public view returns (bytes memory) {
        //bytes memory _featured = abi.encodePacked('"featured":["');
        bytes memory featured20 = getETHFeatured(_owner);
        bytes memory featured721 = abi.encodePacked('"ENS":{"balance":"', '0 ETH","price":"0 USDC","value":"0 USDC"}');
        uint256 len = Featured.length;
        for (uint256 i = 1; i < len; i++) {
            Ticker memory ticker = Tickers[Featured[i]];
            uint256 _bal = iERC20(ticker._addr).balanceOf(_owner);
            if (_bal > 0) {
                uint256 _erc = ticker._erc;
                if (_erc == 20) {
                    featured20 = getFeatured20(ticker._decimals, ticker._addr, _bal, ticker._symbol).concat(featured20);
                } else if (_erc == 721) {
                    featured721 = abi.encodePacked(featured721, LibString.toHexStringChecksummed(ticker._addr), '","');
                }
            }
        }
        return abi.encodePacked('"ERC20":{"', featured20, '"},"ERC721":{"', featured721, '"}');
    }

    function getETHFeatured(address _owner) public view returns (bytes memory _featured) {
        uint256 _bal = _owner.balance;
        (uint256 _price,) = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).getPrice(); // WETH price
        _featured = abi.encodePacked(
            '"ETH":{"_balance":"',
            _bal.toString(),
            '","balance":"',
            _bal.formatDecimal(18, 6),
            '","contract":"","decimals":"18","price":"',
            _price.formatDecimal(6, 3),
            '","symbol":"ETH","totalsupply":"","value":"',
            _bal.calculateUSDCValue(_price, 18).formatDecimal(6, 3),
            '"}'
        );
    }

    function getENSFeatured(address _owner) public view returns (bytes memory _featured) {
        uint256 _bal; // = ENS721.balanceOf(_owner);
        _featured = abi.encodePacked(
            '"ENS":{"balance":"',
            _bal.toString(),
            '","contract":"',
            _owner.toHexStringChecksummed(),
            '","primary":"',
            _owner.getPrimaryName(),
            '"}'
        );
    }

    function getFeatured721(address _token, uint256 _balance, string memory _symbol)
        internal
        view
        returns (bytes memory _featured)
    {
        _featured = abi.encodePacked(
            '"',
            _symbol,
            '":{"balance":"',
            _balance.toString(),
            '","contract":"',
            _token.toHexStringChecksummed(),
            '","symbol":"',
            _symbol,
            '","supply":"',
            _token.getTotalSupply(),
            '","metadata":"',
            _token.getContractURI(),
            '"},'
        );
    }

    function getFeatured20(uint8 _decimals, address _token, uint256 _balance, string memory _symbol)
        internal
        view
        returns (bytes memory _featured)
    {
        (uint256 _price,) = address(_token).getPrice();
        _featured = abi.encodePacked(
            '"',
            _symbol,
            '":{"_balance":"',
            _balance.toString(),
            '","balance":"',
            _balance.formatDecimal(_decimals, 6),
            '","contract":"',
            _token.toHexStringChecksummed(),
            '","decimals":"',
            _decimals.toString(),
            '","price":"',
            _price.formatDecimal(6, 3),
            '","supply":"',
            iERC20(_token).totalSupply().formatDecimal(_decimals, 3),
            '","symbol":"',
            _symbol,
            '","value":"',
            _balance.calculateUSDCValue(_price, _decimals).formatDecimal(6, 3),
            '"},' // appending extra "," here
        );
    }
}
