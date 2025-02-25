// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Utils.sol";
import {LibString} from "solady/utils/LibString.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";
import {Brutalizer} from "../lib/solady/test/utils/Brutalizer.sol";
import {iCheckTheChainEthereum} from "../src/interfaces/ICheckTheChain.sol";
import {iERC165, iERC721Metadata, iERC721ContractMetadata} from "../src/interfaces/IERC.sol";
import {iResolver} from "../src/interfaces/IENS.sol";

contract UtilsTest is Test, Brutalizer {
    using Utils for address;
    using Utils for bytes;
    using Utils for string;
    using LibString for uint256;

    // Known mainnet addresses
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant ENS_NFT = 0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85;
    address constant BAYC = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant PUNKS = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    address constant VITALIK = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    address constant ENS_RESOLVER = 0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41;
    address constant OLD_RESOLVER = 0x226159d592E2b063810a10Ebf6dcbADA94Ed68b8; // Non-standard ENS resolver

    // Test values
    address constant TEST_ADDRESS = 0x1234567890123456789012345678901234567890;
    string constant TEST_STRING = "123456789";
    bytes constant TEST_HEX = hex"1234";

    function setUp() public {
        vm.createSelectFork("mainnet", 21836278); // Use specific block for consistency
        vm.startPrank(address(this));
        vm.stopPrank();
    }

    function test_GetPrice_RealTokens() public view {
        // Test WETH price using real CheckTheChain data
        (uint256 wethPrice, string memory wethPriceStr) = WETH.getPrice();
        assertGt(wethPrice, 0); // Price should exist
        assertGt(bytes(wethPriceStr).length, 0); // String should not be empty

        // Test USDC price (hardcoded to $1)
        (uint256 usdcPrice, string memory usdcPriceStr) = USDC.getPrice();
        assertEq(usdcPrice, 1e6);
        assertEq(usdcPriceStr, "1");

        // Test WBTC price using real CheckTheChain data
        (uint256 wbtcPrice, string memory wbtcPriceStr) = WBTC.getPrice();
        assertGt(wbtcPrice, 0); // Price should exist
        assertGt(bytes(wbtcPriceStr).length, 0); // String should not be empty

        // Test non-token contract (should try both price functions and return 0)
        (uint256 price, string memory priceStr) = address(1234).getPrice();
        assertEq(price, 0);
        assertEq(priceStr, "");
    }

    function test_GetPrice_CTCFallback() public {
        bytes4 checkPriceSelector = bytes4(keccak256("checkPrice(address)"));
        bytes4 checkPriceInETHToUSDCSelector = bytes4(keccak256("checkPriceInETHToUSDC(address)"));

        // Mock CTC price check to fail, forcing fallback to ETH price
        vm.mockCallRevert(address(Utils.CTC), abi.encodeWithSelector(checkPriceSelector, address(WETH)), "FAILED");

        // Mock successful ETH price check
        vm.mockCall(
            address(Utils.CTC),
            abi.encodeWithSelector(checkPriceInETHToUSDCSelector, address(WETH)),
            abi.encode(2000e6, "2000")
        );

        (uint256 price, string memory priceStr) = WETH.getPrice();
        assertEq(price, 2000e6);
        assertEq(priceStr, "2000");
    }

    function test_GetTokenInfo_RealTokens() public {
        // Test WETH info
        assertEq(WETH.getName(), "Wrapped Ether");
        assertEq(WETH.getSymbol(), "WETH");
        assertEq(WETH.getDecimals(), "18");
        assertEq(WETH.getDecimalsUint(), 18);
        string memory wethSupply = WETH.getTotalSupply20(18, 3);
        assertGt(bytes(wethSupply).length, 0);

        // Test USDC info
        assertEq(USDC.getName(), "USD Coin");
        assertEq(USDC.getSymbol(), "USDC");
        assertEq(USDC.getDecimals(), "6");
        assertEq(USDC.getDecimalsUint(), 6);
        string memory usdcSupply = USDC.getTotalSupply20(6, 3);
        assertGt(bytes(usdcSupply).length, 0);

        // Test WBTC info
        assertEq(WBTC.getName(), "Wrapped BTC");
        assertEq(WBTC.getSymbol(), "WBTC");
        assertEq(WBTC.getDecimals(), "8");
        assertEq(WBTC.getDecimalsUint(), 8);
        string memory wbtcSupply = WBTC.getTotalSupply20(8, 3);
        assertGt(bytes(wbtcSupply).length, 0);

        // Test BAYC info
        assertEq(BAYC.getName(), "BoredApeYachtClub");
        assertEq(BAYC.getSymbol(), "BAYC");
        assertEq(BAYC.getTotalSupply721(), "10000");

        // Test failed calls
        // Test failed name call - should return "N/A"
        vm.mockCallRevert(USDC, abi.encodeWithSelector(iERC20.name.selector), "FAILED");
        assertEq(USDC.getName(), "N/A");

        // Test failed symbol call - should return "N/A"
        vm.mockCallRevert(USDC, abi.encodeWithSelector(iERC20.symbol.selector), "FAILED");
        assertEq(USDC.getSymbol(), "N/A");

        // Test failed decimals call - should return "0"
        vm.mockCallRevert(USDC, abi.encodeWithSelector(iERC20.decimals.selector), "FAILED");
        assertEq(USDC.getDecimals(), "0");
        assertEq(USDC.getDecimalsUint(), 0);

        // Test failed totalSupply call - should return "0"
        vm.mockCallRevert(USDC, abi.encodeWithSelector(iERC20.totalSupply.selector), "FAILED");
        assertEq(USDC.getTotalSupply721(), "0");
        assertEq(USDC.getTotalSupply20(18, 3), "0");
    }

    function test_GetENSInfo_RealAddresses() public view {
        // Test Vitalik's ENS with modern resolver
        assertEq(VITALIK.getPrimaryName(), "vitalik.eth");

        bytes32 vitalikNode =
            keccak256(abi.encodePacked(keccak256(abi.encodePacked(bytes32(0), keccak256("eth"))), keccak256("vitalik")));
        assertEq(ENS_RESOLVER.getENSAddress(vitalikNode), VITALIK);

        // Test old resolver that doesn't support addr interface
        bytes32 oldNode =
            keccak256(abi.encodePacked(keccak256(abi.encodePacked(bytes32(0), keccak256("eth"))), keccak256("old")));
        assertEq(OLD_RESOLVER.getENSAddress(oldNode), address(0));

        // Test non-existent name
        bytes32 nonExistentNode = keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked(bytes32(0), keccak256("eth"))),
                keccak256("thisisaverylongnonexistentnamethatshoulddefinitelynotexist")
            )
        );
        assertEq(ENS_RESOLVER.getENSAddress(nonExistentNode), address(0));

        // Test zero address
        assertEq(address(0).getPrimaryName(), "");

        // Test non-existent resolver
        assertEq(address(0xdead).getENSAddress(vitalikNode), address(0));
    }

    function test_TokenBalances_RealTokens() public {
        // Test WETH balance
        vm.deal(VITALIK, 1000 ether); // Give Vitalik some ETH
        uint256 wethBalance = iERC20(WETH).balanceOf(VITALIK);
        assertEq(WETH.getBalance20(VITALIK, 18), Utils.formatDecimal(wethBalance, 18, 6));

        // Test USDC balance - use actual balance at block 21836278
        uint256 usdcBalance = iERC20(USDC).balanceOf(VITALIK);
        string memory expectedBalance = Utils.formatDecimal(usdcBalance, 6, 6);
        assertEq(USDC.getBalance20(VITALIK, 6), expectedBalance);

        // Test BAYC balance
        uint256 baycBalance = iERC721(BAYC).balanceOf(VITALIK);
        assertEq(BAYC.getBalance721(VITALIK), baycBalance.toString());

        // Test zero address
        assertEq(WETH.getBalance20(address(0), 18), "1085.433955");

        // Test failed balance calls
        vm.mockCallRevert(WETH, abi.encodeWithSelector(iERC20.balanceOf.selector), "FAILED");
        assertEq(WETH.getBalance20(VITALIK, 18), "0");
        assertEq(WETH.getBalance721(VITALIK), "0");
    }

    function test_CalculateUSDCValue_RealTokens() public view {
        // Test decimals > 6
        // WETH (18 decimals)
        (uint256 ethPrice,) = WETH.getPrice();
        uint256 ethAmount = 2 ether;
        uint256 expectedValue = (ethAmount * ethPrice) / 1e18;
        assertEq(Utils.calculateUSDCValue(ethAmount, ethPrice, 18), expectedValue);

        // WBTC (8 decimals)
        (uint256 wbtcPrice,) = WBTC.getPrice();
        uint256 wbtcAmount = 100000000; // 1 WBTC
        expectedValue = (wbtcAmount * wbtcPrice) / 1e8;
        assertEq(Utils.calculateUSDCValue(wbtcAmount, wbtcPrice, 8), expectedValue);

        // Test decimals == 6
        // USDC (6 decimals)
        uint256 usdcAmount = 1000000; // $1 USDC
        assertEq(Utils.calculateUSDCValue(usdcAmount, 1e6, 6), usdcAmount);

        // USDT (6 decimals)
        uint256 usdtAmount = 2000000; // $2 USDT
        assertEq(Utils.calculateUSDCValue(usdtAmount, 1e6, 6), usdtAmount);

        // Test decimals < 6
        // Using a hypothetical token with 3 decimals
        uint256 amount = 1000; // 1.000
        uint256 price = 1e6; // $1
        assertEq(Utils.calculateUSDCValue(amount, price, 3), amount * 1000); // Scale up to 6 decimals

        // Test zero cases
        assertEq(Utils.calculateUSDCValue(0, wbtcPrice, 8), 0);
        assertEq(Utils.calculateUSDCValue(wbtcAmount, 0, 8), 0);
    }

    function test_GetTokenURI() public {
        // Test BAYC - Regular IPFS URI
        string memory baycURI = BAYC.getTokenURI(1);
        assertTrue(bytes(baycURI).length > 0);
        assertTrue(LibString.startsWith(baycURI, "ipfs://"));

        // Test data URI
        address mockNFT = address(0x123);
        vm.etch(mockNFT, hex"00");
        vm.mockCall(
            mockNFT,
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 1),
            abi.encode('data:application/json,{"name":"Test"}')
        );
        assertEq(mockNFT.getTokenURI(1), 'data:application/json,{\\"name\\":\\"Test\\"}');

        // Test text/plain data URI
        vm.mockCall(
            mockNFT,
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 2),
            abi.encode("data:text/plain,Hello World")
        );
        assertEq(mockNFT.getTokenURI(2), "data:text/plain,Hello World");

        // Test base64 data URI - should return as-is
        vm.mockCall(
            mockNFT,
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 3),
            abi.encode("data:application/json;base64,eyJuYW1lIjoiVGVzdCJ9")
        );
        assertEq(mockNFT.getTokenURI(3), "data:application/json;base64,eyJuYW1lIjoiVGVzdCJ9");

        // Test HTTP URI with quotes
        vm.mockCall(
            mockNFT,
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 4),
            abi.encode('https://api.example.com/token/"special"')
        );
        assertEq(mockNFT.getTokenURI(4), "https://api.example.com/token/&quot;special&quot;");

        // Test regular HTTP URI
        vm.mockCall(
            mockNFT,
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 5),
            abi.encode("https://api.example.com/token/123")
        );
        assertEq(mockNFT.getTokenURI(5), "https://api.example.com/token/123");

        // Test empty URI
        vm.mockCall(mockNFT, abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 6), abi.encode(""));
        assertEq(mockNFT.getTokenURI(6), "");

        // Test failed call
        vm.mockCallRevert(mockNFT, abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 7), "NOT_FOUND");
        assertEq(mockNFT.getTokenURI(7), "");
    }

    function test_GetTokenURI_MoreFormats() public {
        address mockNFT = address(0x123);
        vm.etch(mockNFT, hex"00");

        // Test data URI with complex JSON
        vm.mockCall(
            mockNFT,
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 1),
            abi.encode('data:application/json,{"name":"Test","description":"A test token","image":"ipfs://..."}')
        );
        string memory result = mockNFT.getTokenURI(1);
        assertTrue(LibString.contains(result, '\\"name\\":\\"Test\\"'));
        assertTrue(LibString.contains(result, '\\"description\\"'));

        // Test data URI with text/plain and quotes
        vm.mockCall(
            mockNFT,
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 2),
            abi.encode('data:text/plain,Hello "World"')
        );
        assertEq(mockNFT.getTokenURI(2), 'data:text/plain,Hello \\"World\\"');

        // Test base64 data URI
        vm.mockCall(
            mockNFT,
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 3),
            abi.encode("data:application/json;base64,eyJuYW1lIjoiVGVzdCJ9")
        );
        assertEq(mockNFT.getTokenURI(3), "data:application/json;base64,eyJuYW1lIjoiVGVzdCJ9");

        // Test empty URI
        vm.mockCall(mockNFT, abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 4), abi.encode(""));
        assertEq(mockNFT.getTokenURI(4), "");

        // Test URI with HTML special chars
        vm.mockCall(
            mockNFT,
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 5),
            abi.encode('https://api.example.com/token/"123"')
        );
        assertEq(mockNFT.getTokenURI(5), "https://api.example.com/token/&quot;123&quot;");
    }

    function test_IsAddress() public pure {
        // Test valid addresses
        assertTrue(Utils.isAddress(bytes("0x1234567890123456789012345678901234567890")));
        assertTrue(Utils.isAddress(bytes("0xabcdef0123456789abcdef0123456789abcdef01")));

        // Test invalid addresses
        assertFalse(Utils.isAddress(bytes("1234567890123456789012345678901234567890"))); // No 0x prefix
        assertFalse(Utils.isAddress(bytes("0x123"))); // Too short
        assertFalse(Utils.isAddress(bytes("0xABCDEF0123456789ABCDEF0123456789ABCDEF01"))); // Uppercase
        assertFalse(Utils.isAddress(bytes("0x123g4567890123456789012345678901234567890"))); // Invalid character
    }

    function test_HexString() public pure {
        // Test prefixed hex string
        assertTrue(Utils.isHexPrefixed("0x1234"));
        assertTrue(Utils.isHexPrefixed("0xabcdef"));
        assertFalse(Utils.isHexPrefixed("1234")); // No prefix
        assertFalse(Utils.isHexPrefixed("0xABCDEF")); // Uppercase
        assertFalse(Utils.isHexPrefixed("0x123g")); // Invalid character

        // Test non-prefixed hex string
        assertTrue(Utils.isHexNoPrefix("1234"));
        assertTrue(Utils.isHexNoPrefix("abcdef"));
        assertFalse(Utils.isHexNoPrefix("0x1234")); // Has prefix
        assertFalse(Utils.isHexNoPrefix("ABCDEF")); // Uppercase
        assertFalse(Utils.isHexNoPrefix("123g")); // Invalid character
    }

    function test_StringToUint() public pure {
        assertEq(Utils.stringToUint("123"), 123);
        assertEq(Utils.stringToUint("0"), 0);
        assertEq(Utils.stringToUint("999999999"), 999999999);
    }

    function test_PrefixedHexStringToBytes() public pure {
        assertEq(Utils.prefixedHexStringToBytes(bytes("0x1234567890abcdef")), hex"1234567890abcdef");
        assertEq(Utils.prefixedHexStringToBytes(bytes("0xabcdef")), hex"abcdef");
    }

    function testFuzz_PrefixedHexStringToBytes(uint16 input) public pure {
        vm.assume(input > 2 && input < 100);
        bytes memory inputBytes = abi.encodePacked(string("0x"), LibBytes.repeat(bytes("1234567890abcdef"), input));
        bytes memory result = Utils.prefixedHexStringToBytes(inputBytes);
        assertEq(result, LibBytes.repeat(hex"1234567890abcdef", input));
    }

    function test_ContractTypeChecks() public view {
        // Test ERC type
        assertEq(BAYC.getERCType(), 721);
        assertEq(WETH.getERCType(), 20);
        assertEq(address(0xdead).getERCType(), 0);
        assertEq(address(this).getERCType(), 0);
    }

    function test_CheckInterface() public view {
        // Test ERC721 interface
        assertTrue(BAYC.checkInterface(type(iERC721).interfaceId));
        assertFalse(WETH.checkInterface(type(iERC721).interfaceId));
        assertFalse(address(0xdead).checkInterface(type(iERC721).interfaceId));
    }

    function test_FormatDecimal() public pure {
        // Test zero value
        assertEq(Utils.formatDecimal(0, 18, 6), "0");

        // Test whole numbers
        assertEq(Utils.formatDecimal(1000000000000000000, 18, 6), "1");
        assertEq(Utils.formatDecimal(2000000000000000000, 18, 6), "2");

        // Test decimals with trailing zeros
        assertEq(Utils.formatDecimal(1200000000000000000, 18, 6), "1.2");
        assertEq(Utils.formatDecimal(1230000000000000000, 18, 6), "1.23");

        // Test decimals with significant digits
        assertEq(Utils.formatDecimal(1234567890123456789, 18, 6), "1.234567");
        assertEq(Utils.formatDecimal(123456789012345678, 18, 6), "0.123456");
        assertEq(Utils.formatDecimal(1234000000000000000, 18, 6), "1.234");

        // Test small decimals
        assertEq(Utils.formatDecimal(100, 18, 6), "0");
        assertEq(Utils.formatDecimal(1, 18, 18), "0.000000000000000001");

        // Test precision > decimals
        assertEq(Utils.formatDecimal(1000, 3, 6), "1000");
        assertEq(Utils.formatDecimal(1234, 3, 6), "1234");

        // Test precision = decimals
        assertEq(Utils.formatDecimal(1234567, 6, 6), "1.234567");

        // Test precision < decimals
        assertEq(Utils.formatDecimal(1234567890, 9, 6), "1.234567");
    }

    function test_getNamehash() public view brutalizeMemory {
        bytes32 result = Utils.getNamehash("vitalik.eth");
        _checkMemory();
        assertEq(result, 0xee6c4522aab0003e8d14cd40a6af439055fd2577951148c14b6cea9a53475835);
    }

    function test_ENSReverseRecord_FullPath() public {
        address testAddr = address(0x123);
        address mockResolver = address(0x456);
        bytes32 node = Utils.ENSReverse.node(testAddr);

        // Mock ENS resolver lookup
        vm.mockCall(address(Utils.ENS), abi.encodeWithSelector(iENS.resolver.selector, node), abi.encode(mockResolver));

        // Mock resolver with code
        vm.etch(mockResolver, hex"01");

        // Mock name lookup
        vm.mockCall(mockResolver, abi.encodeWithSelector(iResolver.name.selector, node), abi.encode("test.eth"));

        // Mock forward resolution
        bytes32 nameNode = Utils.getNamehash("test.eth");
        vm.mockCall(
            address(Utils.ENS), abi.encodeWithSelector(iENS.resolver.selector, nameNode), abi.encode(mockResolver)
        );

        vm.mockCall(mockResolver, abi.encodeWithSelector(iResolver.addr.selector, nameNode), abi.encode(testAddr));

        assertEq(testAddr.getPrimaryName(), "test.eth");
    }

    function test_CalculateUSDCValue_EdgeCases() public pure {
        // Test exact decimal boundaries
        assertEq(Utils.calculateUSDCValue(1e18, 1e6, 18), 1e6); // 1 token at $1
        assertEq(Utils.calculateUSDCValue(1e6, 1e6, 6), 1e6); // 1 token at $1
        assertEq(Utils.calculateUSDCValue(1e3, 1e6, 3), 1e6); // 1 token at $1

        // Test decimal scaling
        assertEq(Utils.calculateUSDCValue(2e18, 5e5, 18), 1e6); // 2 tokens at $0.50
        assertEq(Utils.calculateUSDCValue(1e6, 2e6, 6), 2e6); // 1 token at $2
        assertEq(Utils.calculateUSDCValue(1e3, 5e5, 3), 5e5); // 1 token at $0.50
    }

    function test_TokenBalances_EdgeCases() public {
        address mockToken = address(0x123);
        vm.etch(mockToken, hex"00");

        // Test zero balance
        vm.mockCall(mockToken, abi.encodeWithSelector(iERC20.balanceOf.selector, address(this)), abi.encode(0));
        assertEq(Utils.getBalance20(mockToken, address(this), 18), "0");
        assertEq(Utils.getBalance721(mockToken, address(this)), "0");

        // Test failed call
        vm.mockCallRevert(mockToken, abi.encodeWithSelector(iERC20.balanceOf.selector, address(this)), "FAILED");
        assertEq(Utils.getBalance20(mockToken, address(this), 18), "0");
        assertEq(Utils.getBalance721(mockToken, address(this)), "0");

        // Test large balance with different decimals
        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(iERC20.balanceOf.selector, address(this)),
            abi.encode(1e24) // 1M tokens with 18 decimals
        );
        assertEq(Utils.getBalance20(mockToken, address(this), 18), "1000000");
    }

    function test_TokenSupply_EdgeCases() public {
        address mockToken = address(0x123);
        vm.etch(mockToken, hex"00");

        // Test zero supply
        vm.mockCall(mockToken, abi.encodeWithSelector(iERC20.totalSupply.selector), abi.encode(0));
        assertEq(Utils.getTotalSupply20(mockToken, 18, 6), "0");
        assertEq(Utils.getTotalSupply721(mockToken), "0");

        // Test failed call
        vm.mockCallRevert(mockToken, abi.encodeWithSelector(iERC20.totalSupply.selector), "FAILED");
        assertEq(Utils.getTotalSupply20(mockToken, 18, 6), "0");
        assertEq(Utils.getTotalSupply721(mockToken), "0");

        // Test large supply with different decimals
        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(iERC20.totalSupply.selector),
            abi.encode(1e24) // 1M tokens with 18 decimals
        );
        assertEq(Utils.getTotalSupply20(mockToken, 18, 6), "1000000");
        assertEq(Utils.getTotalSupply20(mockToken, 18, 2), "1000000");
        assertEq(Utils.getTotalSupply20(mockToken, 6, 6), "1000000000000000000");
    }

    function test_TokenMetadata_EdgeCases() public {
        address mockToken = address(0x123);
        vm.etch(mockToken, hex"00");

        // Test failed name call
        vm.mockCallRevert(mockToken, abi.encodeWithSelector(iERC20.name.selector), "FAILED");
        assertEq(Utils.getName(mockToken), "N/A");

        // Test failed symbol call
        vm.mockCallRevert(mockToken, abi.encodeWithSelector(iERC20.symbol.selector), "FAILED");
        assertEq(Utils.getSymbol(mockToken), "N/A");

        // Test failed decimals call
        vm.mockCallRevert(mockToken, abi.encodeWithSelector(iERC20.decimals.selector), "FAILED");
        assertEq(Utils.getDecimals(mockToken), "0");
        assertEq(Utils.getDecimalsUint(mockToken), 0);
    }

    function test_GetPrimaryName() public {
        // Test with vitalik.eth which has a reverse record
        string memory name = Utils.getPrimaryName(0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);
        assertEq(name, "vitalik.eth");

        // Test with address that has no reverse record
        string memory noName = Utils.getPrimaryName(address(0xdead));
        assertEq(noName, "");
    }

    function test_GetNamehash() public {
        // Test single label
        bytes32 ethHash = Utils.getNamehash("eth");
        assertEq(ethHash, 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae);

        // Test two labels
        bytes32 vitalikHash = Utils.getNamehash("vitalik.eth");
        assertEq(vitalikHash, 0xee6c4522aab0003e8d14cd40a6af439055fd2577951148c14b6cea9a53475835);

        // Test three labels
        bytes32 subHash = Utils.getNamehash("sub.vitalik.eth");
        assertEq(subHash, 0x02db957db5283c30c2859ec435b7e24e687166eddf333b9615ed3b91bd063359);
    }

    function test_GetENSAddress() public {
        // Test vitalik.eth resolver
        address resolver = 0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41;
        bytes32 node = Utils.getNamehash("vitalik.eth");
        address addr = Utils.getENSAddress(resolver, node);
        assertEq(addr, 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);

        // Test non-existent name (using a random hash)
        bytes32 nonExistentNode = bytes32(uint256(1)); // Random hash that won't exist
        address noAddr = Utils.getENSAddress(resolver, nonExistentNode);
        assertEq(noAddr, address(0));
    }

    function test_HexValidation() public {
        // Test valid hex with prefix
        assertTrue(Utils.isHexPrefixed("0x1234abcd"));
        assertFalse(Utils.isHexPrefixed("0x1234abcdg")); // invalid char
        assertFalse(Utils.isHexPrefixed("0x123")); // odd length

        // Test valid hex without prefix
        assertTrue(Utils.isHexNoPrefix("1234abcd"));
        assertFalse(Utils.isHexNoPrefix("1234abcdg")); // invalid char
        assertFalse(Utils.isHexNoPrefix("123")); // odd length
    }

    function test_FormatDecimal_EdgeCases() public {
        // Test zero value
        assertEq(Utils.formatDecimal(0, 18, 6), "0");

        // Test value with no decimal places
        assertEq(Utils.formatDecimal(1000, 0, 0), "1000");

        // Test value with more precision than decimals
        assertEq(Utils.formatDecimal(1234567, 6, 8), "1.234567");

        // Test value with trailing zeros in decimals
        assertEq(Utils.formatDecimal(1000000, 6, 6), "1.000000");

        // Test large whole number
        assertEq(Utils.formatDecimal(1234567890123456789000000000, 18, 2), "1234567890.12");
    }
}
