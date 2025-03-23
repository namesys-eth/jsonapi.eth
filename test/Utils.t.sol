// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Utils.sol";
import {LibString} from "solady/utils/LibString.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";
import {iERC20, iERC721, iERC165, iERC721Metadata} from "../src/interfaces/IERC.sol";
import {iENS, iENSReverse, iResolver} from "../src/interfaces/IENS.sol";
import {iCheckTheChainEthereum} from "../src/interfaces/ICheckTheChain.sol";

contract UtilsTest is Test {
    using LibString for *;
    using Utils for *;

    // Known mainnet addresses for testing
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant BAYC = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
    address constant VITALIK = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    address constant ENS_RESOLVER = 0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41;

    function setUp() public {}

    // String/Bytes Utilities Tests
    function test_IsAddress() public pure {
        assertTrue(Utils.isAddress(bytes(VITALIK.toHexString())));
        assertTrue(Utils.isAddress(bytes(WETH.toHexString())));
        assertFalse(Utils.isAddress(bytes("not an address")));
    }

    function test_IsHexPrefixed() public pure {
        assertTrue(Utils.isHexPrefixed(VITALIK.toHexString()));
        assertTrue(Utils.isHexPrefixed(WETH.toHexString()));
        assertFalse(Utils.isHexPrefixed("1234")); // no prefix
    }

    function test_IsNumber() public pure {
        assertTrue(Utils.isNumber("123"));
        assertTrue(Utils.isNumber("0"));
        assertFalse(Utils.isNumber("12.3")); // decimal point
        assertFalse(Utils.isNumber("-123")); // negative
        assertFalse(Utils.isNumber("abc")); // letters
    }

    // Contract Type Tests
    function test_GetERCType() public {
        // Create mock contracts
        address mockERC20 = makeAddr("mockERC20");
        address mockERC721 = makeAddr("mockERC721");
        address mockNonToken = makeAddr("mockNonToken");

        // Etch code to the addresses
        vm.etch(mockERC20, bytes("mock code"));
        vm.etch(mockERC721, bytes("mock code"));
        vm.etch(mockNonToken, bytes("mock code"));

        // Mock ERC721 supportsInterface call for mockERC721
        vm.mockCall(
            mockERC721,
            abi.encodeWithSelector(iERC165.supportsInterface.selector, type(iERC721).interfaceId),
            abi.encode(true)
        );

        // Mock ERC721 supportsInterface call for mockERC20 (should return false)
        vm.mockCall(
            mockERC20,
            abi.encodeWithSelector(iERC165.supportsInterface.selector, type(iERC721).interfaceId),
            abi.encode(false)
        );

        // Mock ERC721 supportsInterface call for mockNonToken (should return false)
        vm.mockCall(
            mockNonToken,
            abi.encodeWithSelector(iERC165.supportsInterface.selector, type(iERC721).interfaceId),
            abi.encode(false)
        );

        // Mock ERC20 decimals call for mockERC20
        vm.mockCall(mockERC20, abi.encodeWithSelector(iERC20.decimals.selector), abi.encode(uint8(18)));

        // Mock decimals to revert for non-token and ERC721
        vm.mockCallRevert(mockNonToken, abi.encodeWithSelector(iERC20.decimals.selector), "REVERT");

        vm.mockCallRevert(mockERC721, abi.encodeWithSelector(iERC20.decimals.selector), "REVERT");

        // Test with mock contracts
        assertEq(Utils.getERCType(mockERC20), 20);
        assertEq(Utils.getERCType(mockERC721), 721);
        assertEq(Utils.getERCType(mockNonToken), 0);

        // Test with zero address
        assertEq(Utils.getERCType(address(0)), 0);

        vm.clearMockedCalls();
    }

    // Token Info Tests
    function test_GetName() public view {
        assertEq(Utils.getName(WETH), "Wrapped Ether");
        assertEq(Utils.getName(USDC), "USD Coin");
        assertEq(Utils.getName(BAYC), "BoredApeYachtClub");
    }

    function test_GetSymbol() public view {
        assertEq(Utils.getSymbol(WETH), "WETH");
        assertEq(Utils.getSymbol(USDC), "USDC");
        assertEq(Utils.getSymbol(BAYC), "BAYC");
    }

    function test_GetTotalSupply721() public view {
        assertEq(Utils.getTotalSupply721(BAYC), "10000");
    }

    function test_GetBalance721() public view {
        assertEq(Utils.getBalance721(BAYC, VITALIK), iERC721(BAYC).balanceOf(VITALIK).toString());
    }

    function test_GetNFTOwner() public view {
        uint256 tokenId = 1234;
        assertEq(Utils.getNFTOwner(BAYC, tokenId), iERC721(BAYC).ownerOf(tokenId).toHexString());
    }

    function test_GetTokenURI() public view {
        uint256 tokenId = 1234;
        assertTrue(bytes(Utils.getTokenURI(BAYC, tokenId)).length > 0);
    }

    // ENS Tests
    function test_GetPrimaryName() public {
        // Test with a real address that has an ENS name
        assertEq(Utils.getPrimaryName(VITALIK), "vitalik.eth");

        // Test with a mock address that doesn't have an ENS name
        address mockAddress = address(0x1234);

        // Mock the ENS reverse node call
        bytes32 mockNode = bytes32(uint256(0x123456));
        vm.mockCall(
            address(Utils.ENSReverse),
            abi.encodeWithSelector(Utils.ENSReverse.node.selector, mockAddress),
            abi.encode(mockNode)
        );

        // Mock the ENS resolver call to return zero address
        vm.mockCall(
            address(Utils.ENS), abi.encodeWithSelector(Utils.ENS.resolver.selector, mockNode), abi.encode(address(0))
        );

        // Should return empty string for address with no ENS name
        assertEq(Utils.getPrimaryName(mockAddress), "");

        vm.clearMockedCalls();
    }

    function test_GetENSAddress() public view {
        bytes32 node = Utils.getNamehash("vitalik.eth");
        assertEq(Utils.getENSAddress(ENS_RESOLVER, node), VITALIK);
        assertEq(Utils.getENSAddress(address(0), node), address(0));
    }

    function test_CheckInterface() public view {
        assertTrue(Utils.checkInterface(BAYC, type(iERC721).interfaceId));
        assertFalse(Utils.checkInterface(address(0), type(iERC721).interfaceId));
        assertFalse(Utils.checkInterface(address(0xdead), type(iERC721).interfaceId));
    }

    // Price Tests
    function test_CheckTheChain() public view {
        // Test USDC (hardcoded price)
        (uint256 price, string memory priceStr) = Utils.checkTheChain(USDC);
        assertEq(price, 1e6);
        assertEq(priceStr, "1");

        // Test WETH
        (price, priceStr) = Utils.checkTheChain(WETH);
        assertTrue(price > 0);
        assertTrue(bytes(priceStr).length > 0);

        // Test invalid token
        (price, priceStr) = Utils.checkTheChain(address(0));
        assertEq(price, 0);
        assertEq(priceStr, "");
    }

    // Numeric Conversion Tests
    function test_ToDecimal() public pure {
        assertEq(Utils.toDecimal(0, 18), "0");
        assertEq(Utils.toDecimal(1e18, 18), "1");
        assertEq(Utils.toDecimal(123e18, 18), "123");
        assertEq(Utils.toDecimal(1234567e15, 18), "1.234");
        assertEq(Utils.toDecimal(1200000e15, 18), "1.2");
        assertEq(Utils.toDecimal(123456e12, 18), "0.123456");
        assertEq(Utils.toDecimal(120000e12, 18), "0.12");
    }

    function test_ToUSDC() public pure {
        // Test zero cases
        assertEq(Utils.toUSDC(0, 1e6, 18), 0);
        assertEq(Utils.toUSDC(1e18, 0, 18), 0);

        // Test different decimal configurations
        assertEq(Utils.toUSDC(1e18, 2e6, 18), 2e6); // 18 decimals (ETH)
        assertEq(Utils.toUSDC(1e6, 2e6, 6), 2e6); // 6 decimals (USDC)
        assertEq(Utils.toUSDC(1e8, 2e6, 8), 2e6); // 8 decimals (WBTC)

        // Test partial amounts
        assertEq(Utils.toUSDC(5e17, 2e6, 18), 1e6); // 0.5 ETH at $2
        assertEq(Utils.toUSDC(5e5, 2e6, 6), 1e6); // 0.5 USDC at $2
        assertEq(Utils.toUSDC(5e7, 2e6, 8), 1e6); // 0.5 WBTC at $2
    }

    function test_StringToUint() public pure {
        assertEq(Utils.stringToUint("0"), 0);
        assertEq(Utils.stringToUint("123"), 123);
        assertEq(Utils.stringToUint("999999999"), 999999999);
    }

    function test_PrefixedHexStringToBytes() public pure {
        bytes memory result = Utils.prefixedHexStringToBytes("0x1234abcd");
        assertEq(result.length, 4);
        assertEq(result[0], bytes1(0x12));
        assertEq(result[1], bytes1(0x34));
        assertEq(result[2], bytes1(0xab));
        assertEq(result[3], bytes1(0xcd));
    }

    function test_GetNamehash() public pure {
        assertEq(Utils.getNamehash("eth"), 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae);
        assertEq(Utils.getNamehash("vitalik.eth"), 0xee6c4522aab0003e8d14cd40a6af439055fd2577951148c14b6cea9a53475835);
        assertEq(
            Utils.getNamehash("sub.vitalik.eth"), 0x02db957db5283c30c2859ec435b7e24e687166eddf333b9615ed3b91bd063359
        );
    }

    function test_PrefixedHexStringToBytes_EdgeCases() public pure {
        // Empty string with prefix
        bytes memory result = Utils.prefixedHexStringToBytes("0x");
        assertEq(result.length, 0);
    }

    function test_GetTokenURI_EdgeCases() public view {
        // Test non-existent token
        assertEq(Utils.getTokenURI(BAYC, 99999), "");

        // Test non-ERC721Metadata contract
        assertEq(Utils.getTokenURI(WETH, 1), "");
    }

    function test_GetPrimaryName_EdgeCases() public {
        bytes32 node = Utils.ENSReverse.node(VITALIK);

        // Test with non-existent resolver
        vm.mockCall(
            address(Utils.ENS), abi.encodeWithSelector(Utils.ENS.resolver.selector, node), abi.encode(address(0x123))
        );

        // Mock the name call to return empty string
        vm.mockCall(address(0x123), abi.encodeWithSelector(iResolver.name.selector, node), abi.encode(""));

        string memory result;
        try this.callGetPrimaryName(VITALIK) returns (string memory name) {
            result = name;
        } catch {
            result = "";
        }

        assertEq(result, "");
        vm.clearMockedCalls();

        // Test with reverting resolver
        vm.mockCallRevert(address(Utils.ENS), abi.encodeWithSelector(Utils.ENS.resolver.selector, node), "REVERT");

        try this.callGetPrimaryName(VITALIK) returns (string memory name) {
            result = name;
        } catch {
            result = "";
        }

        assertEq(result, "");
        vm.clearMockedCalls();
    }

    function callGetPrimaryName(address addr) external view returns (string memory) {
        return Utils.getPrimaryName(addr);
    }

    function test_GetENSAddress_EdgeCases() public {
        bytes32 node = Utils.getNamehash("vitalik.eth");

        // Test with resolver that reverts
        vm.mockCallRevert(ENS_RESOLVER, abi.encodeWithSelector(iResolver.addr.selector, node), "REVERT");
        assertEq(Utils.getENSAddress(ENS_RESOLVER, node), address(0));

        // Test with resolver that returns zero address
        vm.mockCall(ENS_RESOLVER, abi.encodeWithSelector(iResolver.addr.selector, node), abi.encode(address(0)));
        assertEq(Utils.getENSAddress(ENS_RESOLVER, node), address(0));
    }

    function test_IsNumber_EdgeCases() public pure {
        // String with only numeric characters is a number
        assertTrue(Utils.isNumber("123"));
        assertTrue(Utils.isNumber("0"));
        // String with non-numeric characters is not a number
        assertFalse(Utils.isNumber("abc"));
        assertFalse(Utils.isNumber("123abc"));
    }

    // More comprehensive tests for getERCType
    function test_GetERCType_EdgeCases() public {
        // Create a mock contract
        address mockContract = address(0x1234);

        // Mock code length check to return non-empty code
        vm.mockCall(mockContract, abi.encodeWithSelector(bytes4(keccak256("code()"))), abi.encode(bytes("mock code")));

        // Mock supportsInterface to return false for ERC721
        vm.mockCall(
            mockContract,
            abi.encodeWithSelector(iERC165.supportsInterface.selector, type(iERC721).interfaceId),
            abi.encode(false)
        );

        // Mock decimals to revert, simulating a non-ERC20 contract
        vm.mockCallRevert(mockContract, abi.encodeWithSelector(iERC20.decimals.selector), "REVERT");

        // Should return 0 for a contract that's neither ERC20 nor ERC721
        assertEq(Utils.getERCType(mockContract), 0);

        vm.clearMockedCalls();
    }

    // More comprehensive tests for toDecimal
    function test_ToDecimal_EdgeCases() public pure {
        // Test with various decimal places
        assertEq(Utils.toDecimal(1234567890, 0), "1234567890");
        assertEq(Utils.toDecimal(1234567890, 9), "1.234567");

        // Test with very small values (< 1)
        assertEq(Utils.toDecimal(123456, 9), "0.000123");
        assertEq(Utils.toDecimal(123000, 9), "0.000123");

        // Test with trailing zeros in decimal part
        assertEq(Utils.toDecimal(1230000, 6), "1.23");

        // Test with precision capping
        assertEq(Utils.toDecimal(123456, 5), "1.23456"); // precision <= decimals
        assertEq(Utils.toDecimal(123456, 4), "12.3456"); // precision <= decimals
        assertEq(Utils.toDecimal(123456, 3), "123.456"); // precision <= decimals
        assertEq(Utils.toDecimal(123456789, 9), "0.123456"); // precision (6) < decimals (9)
    }

    // More comprehensive tests for toUSDC
    function test_ToUSDC_EdgeCases() public pure {
        // Test with various decimal combinations
        assertEq(Utils.toUSDC(1e18, 1e6, 18), 1e6); // 1 token at $1
        assertEq(Utils.toUSDC(1e6, 1e6, 6), 1e6); // 1 token at $1
        assertEq(Utils.toUSDC(1e6, 1e6, 3), 1e9); // 1 token at $1 with 3 decimals
        assertEq(Utils.toUSDC(1e6, 1e6, 9), 1e3); // 1 token at $1 with 9 decimals
    }

    function test_GetName_NonERC20() public {
        // Test with a mock contract that doesn't implement name()
        address mockContract = makeAddr("mockContract");

        // Etch code to the address so it's not empty
        vm.etch(mockContract, bytes("mock code"));

        // Mock a revert when calling name()
        vm.mockCallRevert(mockContract, abi.encodeWithSelector(iERC20.name.selector), "REVERT");
        assertEq(Utils.getName(mockContract), "N/A");

        assertEq(Utils.getName(address(this)), "N/A");

        vm.clearMockedCalls();
    }

    function test_GetSymbol_NonERC20() public {
        // Test with a mock contract that doesn't implement symbol()
        address mockContract = makeAddr("mockContract");

        // Etch code to the address so it's not empty
        vm.etch(mockContract, bytes("mock code"));

        // Mock a revert when calling symbol()
        vm.mockCallRevert(mockContract, abi.encodeWithSelector(iERC20.symbol.selector), "REVERT");
        assertEq(Utils.getSymbol(mockContract), "N/A");

        // Test with a zero address
        vm.makePersistent(address(this));
        assertEq(Utils.getSymbol(address(this)), "N/A");

        vm.clearMockedCalls();
    }

    function test_GetTokenURI_WithEscaping() public {
        // Mock a tokenURI call that returns a string with quotes
        uint256 tokenId = 1234;
        vm.mockCall(
            BAYC,
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, tokenId),
            abi.encode('{"name":"Test Token","description":"A test token with \"quotes\""}')
        );

        string memory uri = Utils.getTokenURI(BAYC, tokenId);
        assertTrue(bytes(uri).length > 0);
        // The quotes should be escaped
        assertTrue(!LibString.contains(uri, '""'));

        vm.clearMockedCalls();
    }

    function test_GetNamehash_ComplexDomains() public pure {
        // Test with more complex domain names
        bytes32 expected = 0x509d8ba67ae24903fb65dcd447b9bfce43b3072957a73072cb341012ab7cf826;
        assertEq(Utils.getNamehash("test.subdomain.vitalik.eth"), expected);

        // Test with a very long domain name
        expected = 0xadefdb991bd96b453bac7538fcfefc06d3ad1936360193f0cc852521b7da430b;
        assertEq(Utils.getNamehash("this.is.a.very.long.domain.name.with.many.subdomains.eth"), expected);

        // Test with a single character domain
        expected = 0x83853f8c4ca91ae85231d68dec421e7d9210f65860b863a574dfc0dc0c7e815e;
        assertEq(Utils.getNamehash("a"), expected);
    }

    function test_CheckTheChain_MoreTokens() public view {
        // Test with a token that requires fallback to checkPriceInETHToUSDC
        address LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

        (uint256 price, string memory priceStr) = Utils.checkTheChain(LINK);
        assertTrue(price > 0);
        assertTrue(bytes(priceStr).length > 0);

        // Test with a non-token address that should fail both price checks
        (price, priceStr) = Utils.checkTheChain(address(this));
        assertEq(price, 0);
        assertEq(priceStr, "");
    }

    function test_ToDecimal_MoreEdgeCases() public pure {
        // Test with very large numbers
        assertEq(
            Utils.toDecimal(type(uint256).max, 0),
            "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        );

        // Test with large decimals
        assertEq(Utils.toDecimal(1, 77), "0");

        // Test with precision edge cases
        assertEq(Utils.toDecimal(1234567890, 10), "0.123456");
        assertEq(Utils.toDecimal(1234567890, 5), "12345.6789");

        // Test with trailing zeros in whole part
        assertEq(Utils.toDecimal(1000000e18, 18), "1000000");

        // Test with exact decimal precision
        assertEq(Utils.toDecimal(123456, 6), "0.123456");

        // Test when precision is greater than decimals
        assertEq(Utils.toDecimal(123456, 3), "123.456"); // precision capped at decimals
        assertEq(Utils.toDecimal(123, 2), "1.23"); // precision capped at decimals
        assertEq(Utils.toDecimal(12, 1), "1.2"); // precision capped at decimals
    }

    function test_GetBalance721_EdgeCases() public view {
        // Test with non-ERC721 contract
        assertEq(Utils.getBalance721(address(this), VITALIK), "0");

        // Test with zero address
        assertEq(Utils.getBalance721(BAYC, address(0)), "0");
    }

    function test_GetNFTOwner_EdgeCases() public view {
        // Test with non-existent token ID
        assertEq(Utils.getNFTOwner(BAYC, 99999), "0x0000000000000000000000000000000000000000");

        // Test with non-ERC721 contract
        assertEq(Utils.getNFTOwner(address(this), 1), "0x0000000000000000000000000000000000000000");
    }

    function test_CheckInterface_MoreCases() public {
        // Create a mock contract
        address mockContract = makeAddr("mockContract");

        // Need to mock code length check first by etching code to the address
        vm.etch(mockContract, bytes("mock code"));

        // Mock a successful interface check
        bytes4 supportedInterface = 0x36372b07;
        vm.mockCall(
            mockContract,
            abi.encodeWithSelector(iERC165.supportsInterface.selector, supportedInterface),
            abi.encode(true)
        );

        // Test the supported interface
        assertTrue(Utils.checkInterface(mockContract, supportedInterface));

        // Mock a failed interface check
        bytes4 unsupportedInterface = 0x12345678;
        vm.mockCall(
            mockContract,
            abi.encodeWithSelector(iERC165.supportsInterface.selector, unsupportedInterface),
            abi.encode(false)
        );

        // Test the unsupported interface
        assertFalse(Utils.checkInterface(mockContract, unsupportedInterface));

        // Test with non-existent interface (should return false)
        assertFalse(Utils.checkInterface(address(0), 0x12345678));

        vm.clearMockedCalls();
    }

    function test_GetTotalSupply721_EdgeCases() public {
        // Test with non-ERC721 contract
        assertEq(Utils.getTotalSupply721(address(this)), "0");

        // Test with contract that reverts on totalSupply
        vm.mockCallRevert(BAYC, abi.encodeWithSelector(iERC20.totalSupply.selector), "REVERT");
        assertEq(Utils.getTotalSupply721(BAYC), "0");
        vm.clearMockedCalls();
    }

    function test_ToUSDC_AllDecimals() public pure {
        // Test with all possible decimal configurations (0-18)
        for (uint8 i = 0; i <= 18; i++) {
            uint256 balance = 1 * 10 ** i; // 1 token with i decimals
            uint256 price = 2 * 10 ** 6; // $2 price in USDC (6 decimals)

            uint256 expectedValue;
            if (i > 6) {
                // Decimals > 6: divide by 10^(i-6)
                expectedValue = (balance * price) / 10 ** i;
            } else if (i < 6) {
                // Decimals < 6: multiply by 10^(6-i)
                expectedValue = ((balance * price) / 1000000) * 10 ** (6 - i);
            } else {
                // Decimals = 6: direct conversion
                expectedValue = (balance * price) / 1000000;
            }

            // Test each decimal configuration individually
            assertEq(Utils.toUSDC(balance, price, i), expectedValue);
        }
    }

    function test_IsAddress_MoreCases() public pure {
        // Test with valid lowercase address format (normalized by ENS/DNS)
        assertTrue(Utils.isAddress(bytes("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")));

        // These should fail as isAddress only accepts lowercase hex
        assertFalse(Utils.isAddress(bytes("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")));
        assertFalse(Utils.isAddress(bytes("0XD8DA6BF26964AF9D7EED9E03E53415D37AA96045")));
    }

    function test_GetTokenURI_NonERC721Metadata() public {
        // Test with a contract that doesn't implement tokenURI
        string memory uri = Utils.getTokenURI(WETH, 1);
        assertEq(uri, "");

        // Test with a contract that reverts on tokenURI
        vm.mockCallRevert(BAYC, abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 1), "REVERT");
        uri = Utils.getTokenURI(BAYC, 1);
        assertEq(uri, "");
        vm.clearMockedCalls();
    }
}
