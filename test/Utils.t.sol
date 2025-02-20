// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Utils.sol";
import "./mocks/SoladyToken.sol";
import "./mocks/SoladyNFT.sol";
import {LibString} from "solady/utils/LibString.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";
import "./mocks/NonToken.sol";
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

    SoladyToken public token;
    SoladyNFT public nft;
    NonToken public nonToken;

    function setUp() public {
        vm.createSelectFork("mainnet", 21836278); // Use specific block for consistency
        vm.startPrank(address(this));
        token = new SoladyToken();
        nft = new SoladyNFT();
        nonToken = new NonToken();
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
        (uint256 price, string memory priceStr) = address(nonToken).getPrice();
        assertEq(price, 0);
        assertEq(priceStr, "");
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

        // Test non-existent contract
        assertEq(address(token).getName(), "Test Token");
        assertEq(address(token).getSymbol(), "TEST");
        assertEq(address(token).getDecimals(), "18");
        assertEq(address(token).getDecimalsUint(), 18);
        assertEq(address(token).getTotalSupply20(18, 3), "1000000");

        // Test failed calls
        // Test failed name call - should return "N/A"
        vm.mockCallRevert(address(token), abi.encodeWithSelector(iERC20.name.selector), "FAILED");
        assertEq(address(token).getName(), "N/A");

        // Test failed symbol call - should return "N/A"
        vm.mockCallRevert(address(token), abi.encodeWithSelector(iERC20.symbol.selector), "FAILED");
        assertEq(address(token).getSymbol(), "N/A");

        // Test failed decimals call - should return "0"
        vm.mockCallRevert(address(token), abi.encodeWithSelector(iERC20.decimals.selector), "FAILED");
        assertEq(address(token).getDecimals(), "0");
        assertEq(address(token).getDecimalsUint(), 0);

        // Test failed totalSupply call - should return "0"
        vm.mockCallRevert(address(token), abi.encodeWithSelector(iERC20.totalSupply.selector), "FAILED");
        assertEq(address(token).getTotalSupply721(), "0");
        assertEq(address(token).getTotalSupply20(18, 3), "0");
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
        vm.mockCallRevert(address(token), abi.encodeWithSelector(iERC20.balanceOf.selector), "FAILED");
        assertEq(address(token).getBalance20(VITALIK, 18), "0");
        assertEq(address(token).getBalance721(VITALIK), "0");
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
        // Test BAYC - Regular HTTP URI
        string memory baycURI = BAYC.getTokenURI(1);
        assertTrue(bytes(baycURI).length > 0);
        assertTrue(LibString.startsWith(baycURI, "ipfs://"));

        // Test non-existent contract
        address deadContract = address(0xdead);
        vm.expectRevert(Utils.ContractNotFound.selector);
        deadContract.getTokenURI(1);

        // Test non-ERC721Metadata contract (USDC)
        vm.expectRevert(Utils.NotERC721Metadata.selector);
        USDC.getTokenURI(1);
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

    function test_StringToUint() public {
        assertEq(Utils.stringToUint("123"), 123);
        assertEq(Utils.stringToUint("0"), 0);
        assertEq(Utils.stringToUint("999999999"), 999999999);

        vm.expectRevert(Utils.NotANumber.selector);
        Utils.stringToUint("abc");

        vm.expectRevert(Utils.NotANumber.selector);
        Utils.stringToUint("12.34");

        vm.expectRevert(Utils.NotANumber.selector);
        Utils.stringToUint("-123");
    }

    function test_PrefixedHexStringToBytes() public {
        assertEq(Utils.prefixedHexStringToBytes(bytes("0x1234")), hex"1234");
        assertEq(Utils.prefixedHexStringToBytes(bytes("0xabcdef")), hex"abcdef");

        vm.expectRevert(Utils.InvalidInput.selector);
        Utils.prefixedHexStringToBytes(bytes("1234")); // No prefix

        vm.expectRevert(Utils.InvalidInput.selector);
        Utils.prefixedHexStringToBytes(bytes("0x")); // Empty

        vm.expectRevert(Utils.OddHexLength.selector);
        Utils.prefixedHexStringToBytes(bytes("0x123")); // Odd length

        vm.expectRevert(Utils.InvalidInput.selector);
        Utils.prefixedHexStringToBytes(bytes("0xABCDEF")); // Uppercase

        vm.expectRevert(Utils.InvalidInput.selector);
        Utils.prefixedHexStringToBytes(bytes("0x123g")); // Invalid character
    }

    function test_ContractTypeChecks() public view {
        // Test ERC type
        assertEq(BAYC.getERCType(), 721);
        assertEq(WETH.getERCType(), 20);
        assertEq(address(0xdead).getERCType(), 0);
        assertEq(address(nonToken).getERCType(), 0);
    }

    function test_CheckInterface() public {
        // Test ERC721 interface
        assertTrue(BAYC.checkInterface(type(iERC721).interfaceId));
        assertFalse(WETH.checkInterface(type(iERC721).interfaceId));

        // Test non-existent contract
        assertFalse(address(0xdead).checkInterface(type(iERC721).interfaceId));

        // Test failed supportsInterface call
        vm.mockCall(
            address(nonToken), abi.encodeWithSelector(iERC165.supportsInterface.selector), abi.encode(bytes32(0))
        );
        assertFalse(address(nonToken).checkInterface(type(iERC721).interfaceId));
    }

    function test_GetOwner() public {
        // Test BAYC owner
        string memory owner = BAYC.getOwner(1);
        assertGt(bytes(owner).length, 0);
        assertTrue(Utils.isAddress(bytes(owner)));

        // Test failed ownerOf call
        vm.mockCall(address(nft), abi.encodeWithSelector(iERC721.ownerOf.selector), abi.encode(address(0)));
        assertEq(address(nft).getOwner(1), "0x0000000000000000000000000000000000000000");
    }

    function test_FormatDecimal() public {
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

        // Test invalid decimals
        vm.expectRevert(Utils.InvalidDecimals.selector);
        Utils.formatDecimal(1, 78, 6);
    }

    function test_CalculateUSDCValue_ErrorCases() public {
        // Test invalid decimals
        vm.expectRevert(Utils.InvalidDecimals.selector);
        Utils.calculateUSDCValue(1, 1, 78);
    }
}
