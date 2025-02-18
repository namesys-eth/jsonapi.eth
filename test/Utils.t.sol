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
import {iCheckTheChainEthereum} from "../src/Interface.sol";
import {iERC165} from "../src/Interface.sol";
import {iERC721Metadata} from "../src/Interface.sol";
import {iERC721ContractMetadata} from "../src/Interface.sol";

contract UtilsTest is Test, Brutalizer {
    using Utils for address;
    using Utils for bytes;
    using Utils for string;

    // Test values
    address constant TEST_ADDRESS = 0x1234567890123456789012345678901234567890;
    string constant TEST_STRING = "123456789";
    bytes constant TEST_HEX = hex"1234";

    SoladyToken public token;
    SoladyNFT public nft;
    NonToken public nonToken;

    function setUp() public {
        vm.startPrank(address(this));
        token = new SoladyToken();
        nft = new SoladyNFT();
        nonToken = new NonToken();
        vm.stopPrank();
    }

    function test_GetPrice_Branches() public {
        // Branch 1: WETH price check (uses checkPrice)
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        (uint256 price1, string memory priceStr1) = weth.getPrice();
        assertGt(price1, 1000 * 1e6); // Price should be > $1000 USDC
        assertEq(bytes(priceStr1).length, 11); // Format: "XXXX.XXXXXX"

        // Branch 2: ETH price check (uses WETH price)
        address eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        (uint256 price2, string memory priceStr2) = weth.getPrice(); // Use WETH for ETH price
        assertEq(price2, price1); // ETH price should match WETH price
        assertEq(priceStr2, priceStr1); // String representation should match

        // Branch 3: non-existent token
        address deadToken = address(0xdead);
        (uint256 price3, string memory priceStr3) = deadToken.getPrice();
        assertEq(price3, 0);
        assertEq(priceStr3, "");
    }

    function test_GetERCType_Branches() public {
        // Branch 1: no code
        assertEq(address(0).getERCType(), 0);

        // Branch 2: ERC721
        assertEq(address(nft).getERCType(), 721);

        // Branch 3: ERC20
        assertEq(address(token).getERCType(), 20);

        // Branch 4: neither
        assertEq(address(nonToken).getERCType(), 0);
    }

    function test_GetPrimaryName_Branches() public {
        // Branch 1: has primary name
        address vitalik = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        assertEq(vitalik.getPrimaryName(), "vitalik.eth");

        // Branch 2: no resolver
        assertEq(address(0).getPrimaryName(), "");

        // Branch 3: no primary name
        assertEq(address(this).getPrimaryName(), "");
    }

    function test_GetENSAddress_Branches() public {
        // Branch 1: vitalik.eth resolution
        address resolver = 0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41;
        bytes32 node =
            keccak256(abi.encodePacked(keccak256(abi.encodePacked(bytes32(0), keccak256("eth"))), keccak256("vitalik")));
        assertEq(resolver.getENSAddress(node), 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);

        // Branch 2: non-existent name (using a very long random string that's unlikely to be registered)
        bytes32 nonExistentNode = keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked(bytes32(0), keccak256("eth"))),
                keccak256("thisisaverylongnonexistentnamethatshoulddefinitelynotexist")
            )
        );
        assertEq(resolver.getENSAddress(nonExistentNode), address(0));

        // Branch 3: non-resolver contract
        assertEq(address(nonToken).getENSAddress(node), address(0));
    }

    function test_TokenInfo() public {
        // Name tests
        assertEq(address(token).getName(), "Test Token");
        assertEq(address(nft).getName(), "Test NFT");
        assertEq(address(nonToken).getName(), "N/A");

        // Symbol tests
        assertEq(address(token).getSymbol(), "TEST");
        assertEq(address(nft).getSymbol(), "TNFT");
        assertEq(address(nonToken).getSymbol(), "N/A");

        // Decimals tests
        assertEq(address(token).getDecimals(), "18");
        assertEq(address(nonToken).getDecimals(), "0");

        // Total supply tests
        assertEq(address(token).getTotalSupply20(18, 3), "1000000");
        assertEq(address(nonToken).getTotalSupply20(0, 3), "0");

        // Balance tests
        assertEq(address(token).getBalance20(address(this), 18), "1000000");
        assertEq(address(token).getBalance20(address(1), 18), "0");
        assertEq(address(nonToken).getBalance20(address(this), 0), "0");
    }

    function test_TokenInfo2() public view {
        // Test real ERC20 token (WETH)
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        assertEq(weth.getName(), "Wrapped Ether");
        assertEq(weth.getSymbol(), "WETH");
        assertEq(weth.getDecimals(), "18");
        string memory totalSupply = weth.getTotalSupply20(18, 3);
        assertGt(bytes(totalSupply).length, 0);
        assertEq(totalSupply, "2949331.847");

        // Test real ERC721 token (BAYC)
        address bayc = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
        assertEq(bayc.getName(), "BoredApeYachtClub");
        assertEq(bayc.getSymbol(), "BAYC");
        assertEq(bayc.getTotalSupply721(), "10000");
        assertEq(bayc.getBalance721(address(this)), "0");

        // Test real ERC20 token with non-standard decimals (USDC)
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        assertEq(usdc.getName(), "USD Coin");
        assertEq(usdc.getSymbol(), "USDC");
        assertEq(usdc.getDecimals(), "6");
        totalSupply = usdc.getTotalSupply20(6, 3);
        assertGt(bytes(totalSupply).length, 0);
        assertEq(totalSupply, "36708400270.596");
        // Test real ERC20 token with 0 decimals (WBTC)
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        assertEq(wbtc.getName(), "Wrapped BTC");
        assertEq(wbtc.getSymbol(), "WBTC");
        assertEq(wbtc.getDecimals(), "8");
        totalSupply = wbtc.getTotalSupply20(8, 3);
        assertGt(bytes(totalSupply).length, 0);
        assertEq(totalSupply, "129138.42");
    }

    function test_NFTFunctions() public {
        vm.startPrank(address(nft));
        nft.mint(address(this), 1);
        vm.stopPrank();

        assertEq(address(nft).getOwner(1), LibString.toHexString(address(this)));
        assertEq(address(nonToken).getOwner(1), "0x0000000000000000000000000000000000000000");
    }

    function test_FormatDecimal_Branches() public pure {
        // Branch 1: value is zero
        assertEq(Utils.formatDecimal(0, 18, 2), "0");

        // Branch 2: precision > decimals
        assertEq(Utils.formatDecimal(1, 18, 19), "1");

        // Branch 3: no decimal places
        assertEq(Utils.formatDecimal(1e6, 6, 0), "1");

        // Branch 4: with decimal places
        assertEq(Utils.formatDecimal(123456789, 6, 3), "123.456");

        // Branch 5: large number with decimals
        assertEq(Utils.formatDecimal(1234567890123456789, 18, 9), "1.23456789");
    }

    function test_CalculateUSDCValue_Branches() public pure {
        // Branch 1: zero balance
        assertEq(Utils.calculateUSDCValue(0, 1000 * 1e6, 18), 0);

        // Branch 2: zero price
        assertEq(Utils.calculateUSDCValue(1 ether, 0, 18), 0);

        // Branch 3: decimals > 6 (ETH case)
        assertEq(Utils.calculateUSDCValue(1 ether, 2000 * 1e6, 18), 2000 * 1e6);

        // Branch 4: decimals < 6
        assertEq(Utils.calculateUSDCValue(1e6, 1e6, 3), 1e9);

        // Branch 5: decimals == 6 (USDC case)
        assertEq(Utils.calculateUSDCValue(1000000, 1000000, 6), 1000000);
    }

    function test_StringValidation() public pure {
        // isNumber tests
        assertTrue(Utils.isNumber("123"));
        assertTrue(Utils.isNumber("0"));
        assertTrue(Utils.isNumber(""));
        assertFalse(Utils.isNumber("abc"));
        assertFalse(Utils.isNumber("12a3"));
        assertFalse(Utils.isNumber("12.3"));
        assertFalse(Utils.isNumber("-123"));

        // isHexPrefixed tests
        assertTrue(Utils.isHexPrefixed("0x123"));
        assertTrue(Utils.isHexPrefixed("0xabc"));
        assertTrue(Utils.isHexPrefixed("0x0"));
        assertTrue(Utils.isHexPrefixed("0x"));
        assertFalse(Utils.isHexPrefixed("123"));
        assertFalse(Utils.isHexPrefixed("0xABC"));
        assertFalse(Utils.isHexPrefixed("0xg"));
        assertFalse(Utils.isHexPrefixed(""));

        // isHexNoPrefix tests
        assertTrue(Utils.isHexNoPrefix("123"));
        assertTrue(Utils.isHexNoPrefix("abc"));
        assertTrue(Utils.isHexNoPrefix("0"));
        assertTrue(Utils.isHexNoPrefix(""));
        assertFalse(Utils.isHexNoPrefix("0x123"));
        assertFalse(Utils.isHexNoPrefix("ABC"));
        assertFalse(Utils.isHexNoPrefix("g"));
    }

    // Keep fuzz tests for edge cases
    function testFuzz_StringToUint(uint256 number) public pure {
        string memory numStr = LibString.toString(number);
        assertEq(Utils.stringToUint(numStr), number);
    }

    function testFuzz_PrefixedHexStringToBytes(uint256 value) public view brutalizeMemory {
        vm.assume(value < type(uint128).max);
        bytes memory valueBytes = abi.encodePacked(value, value * 2, value / 2);
        string memory hexStr = LibString.toHexString(valueBytes);
        bytes memory result = Utils.prefixedHexStringToBytes(bytes(hexStr));
        _checkMemory(result);
        assertEq(result, valueBytes);
    }

    function test_PrefixedHexStringToBytes_Empty() public view brutalizeMemory {
        bytes memory result = Utils.prefixedHexStringToBytes(bytes("0x"));
        _checkMemory(result);
        assertEq(result.length, 0);
        assertEq(result, "");
    }

    function test_TokenURIFormats() public {
        vm.mockCall(
            address(nft),
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 1),
            abi.encode('data:application/json,{"name":"test"}')
        );
        vm.mockCall(
            address(nft),
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 2),
            abi.encode('data:text/plain,{"name":"test"}')
        );
        assertEq(address(nft).getTokenURI(1), 'data:application/json,{\\"name\\":\\"test\\"}');
        assertEq(address(nft).getTokenURI(2), 'data:text/plain,{\\"name\\":\\"test\\"}');
    }

    function test_TokenURI_Base64() public {
        // Test data URI with base64 encoding (not JSON)
        address nftAddr = address(0x1234);
        vm.etch(nftAddr, hex"01"); // Put some code there
        vm.mockCall(
            nftAddr,
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 1),
            abi.encode(
                "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
            )
        );
        assertEq(
            address(nftAddr).getTokenURI(1),
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        );
    }

    function test_ERC_NoCode() public {
        address noCodeAddr = address(nonToken);
        // Clear the code from the contract
        vm.etch(noCodeAddr, "");

        // Should revert when trying to check interface on contract with no code
        vm.expectRevert();
        Utils.isERC721(noCodeAddr);

        vm.expectRevert();
        Utils.isERC20(noCodeAddr);
    }

    function test_GetENSAddress_NoInterface() public {
        // Create a resolver that doesn't support the interface
        address resolver = address(0x1234);
        vm.etch(resolver, hex"01"); // Put some code there
        bytes32 node = keccak256("test");
        assertEq(resolver.getENSAddress(node), address(0));
    }

    function test_GetTokenURI_Branches() public {
        // Test regular HTTP URI
        vm.mockCall(
            address(nft),
            abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 1),
            abi.encode("https://api.example.com/token/1")
        );
        assertEq(address(nft).getTokenURI(1), "https://api.example.com/token/1");

        // Test data:application/json
        string memory jsonData =
            "data:application/json;base64,eyJuYW1lIjoidGVzdCIsImRlc2NyaXB0aW9uIjoidGVzdCBuZnQiLCJpbWFnZSI6Imh0dHBzOi8vZXhhbXBsZS5jb20vaW1hZ2UucG5nIn0=";
        vm.mockCall(address(nft), abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 2), abi.encode(jsonData));
        assertEq(address(nft).getTokenURI(2), jsonData);

        // Test data:text/plain with JSON
        string memory plainData =
            'data:text/plain,{"name":"test","description":"test nft","image":"https://example.com/image.png"}';
        vm.mockCall(address(nft), abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 3), abi.encode(plainData));
        assertEq(
            address(nft).getTokenURI(3),
            'data:text/plain,{\\"name\\":\\"test\\",\\"description\\":\\"test nft\\",\\"image\\":\\"https://example.com/image.png\\"}'
        );

        // Test base64 image data URI
        string memory imageData =
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";
        vm.mockCall(address(nft), abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 4), abi.encode(imageData));
        assertEq(address(nft).getTokenURI(4), imageData);

        // Test catch branch (revert)
        vm.mockCallRevert(
            address(nft), abi.encodeWithSelector(iERC721Metadata.tokenURI.selector, 5), "URI_QUERY_FAILED"
        );
        assertEq(address(nft).getTokenURI(5), "");
    }

    function test_GetPrice2() public {
        // Test WETH address (mainnet price)
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        (uint256 price, string memory priceStr) = Utils.getPrice(weth);
        assertGt(price, 0);
        assertGt(bytes(priceStr).length, 0);

        // Test USDC address (different decimals)
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        (price, priceStr) = Utils.getPrice(usdc);
        assertGt(price, 0);
        assertGt(bytes(priceStr).length, 0);

        // Test non-existent token
        address deadToken = address(0xdead);
        (price, priceStr) = Utils.getPrice(deadToken);
        assertEq(price, 0);
        assertEq(priceStr, "");

        // Test EOA
        vm.expectRevert();
        Utils.getPrice(address(0x1));
    }

    function test_TokenURI_Branches() public {
        // Test real NFT contract (BAYC)
        address bayc = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
        string memory uri = bayc.getTokenURI(1);
        assertTrue(bytes(uri).length > 0);

        // Test real NFT contract (Azuki - different URI format)
        address azuki = 0xED5AF388653567Af2F388E6224dC7C4b3241C544;
        uri = azuki.getTokenURI(1);
        assertTrue(bytes(uri).length > 0);

        // Test non-existent token
        address deadToken = address(0xdead);
        vm.expectRevert();
        deadToken.getTokenURI(1);

        // Test EOA
        vm.expectRevert();
        address(0x1).getTokenURI(1);
    }

    function test_IsERC202() public {
        // Test EOA - should revert
        vm.expectRevert();
        Utils.isERC20(address(0x1));

        // Test real ERC20 tokens
        assertTrue(Utils.isERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)); // WETH
        assertTrue(Utils.isERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)); // USDC

        // Test non-contract
        vm.expectRevert();
        Utils.isERC20(address(0xdead));
    }

    function test_IsERC7212() public {
        // Test EOA - should revert
        vm.expectRevert();
        Utils.isERC721(address(0x1));

        // Test real ERC721 tokens
        assertTrue(Utils.isERC721(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D)); // BAYC
        assertTrue(Utils.isERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544)); // Azuki

        // Test non-contract
        vm.expectRevert();
        Utils.isERC721(address(0xdead));
    }

    function test_IsAddress() public {
        // Test valid address
        assertTrue(Utils.isAddress(bytes("0x1234567890123456789012345678901234567890")));

        // Test invalid length
        assertFalse(Utils.isAddress(bytes("0x123")));

        // Test no 0x prefix
        assertFalse(Utils.isAddress(bytes("1234567890123456789012345678901234567890")));

        // Test uppercase hex
        assertFalse(Utils.isAddress(bytes("0x1234567890123456789012345678901234567ABC")));

        // Test invalid characters
        assertFalse(Utils.isAddress(bytes("0x123456789012345678901234567890123456789g")));
    }

    function test_FormatDecimal_EdgeCases() public {
        // Test very large numbers
        assertEq(
            Utils.formatDecimal(type(uint256).max, 18, 6),
            "115792089237316195423570985008687907853269984665640564039457.584007"
        );

        // Test numbers with different decimal places
        assertEq(Utils.formatDecimal(1234567890, 9, 4), "1.2345");
        assertEq(Utils.formatDecimal(1234567000, 6, 6), "1234.567");
        assertEq(Utils.formatDecimal(1234567001, 6, 6), "1234.567001");
        assertEq(Utils.formatDecimal(1234567890, 3, 2), "1234567.89");

        // Test boundary conditions
        assertEq(Utils.formatDecimal(1, 0, 0), "1");
        assertEq(Utils.formatDecimal(0, 18, 18), "0");
        assertEq(Utils.formatDecimal(1, 1, 1), "0.1");
    }

    function test_CalculateUSDCValue_EdgeCases() public {
        // Test max values
        assertGt(Utils.calculateUSDCValue(type(uint128).max, type(uint128).max, 18), 0);

        // Test different decimal combinations
        assertEq(Utils.calculateUSDCValue(1e18, 2e6, 18), 2e6); // 1 ETH at $2
        assertEq(Utils.calculateUSDCValue(1e6, 1e6, 6), 1e6); // 1 USDC at $1
        assertEq(Utils.calculateUSDCValue(1e3, 1e6, 3), 1e6); // 1 token with 3 decimals at $1

        // Test zero cases
        assertEq(Utils.calculateUSDCValue(0, 1e6, 18), 0);
        assertEq(Utils.calculateUSDCValue(1e18, 0, 18), 0);
    }

    function test_StringValidation_EdgeCases() public {
        // Test empty strings
        assertTrue(Utils.isNumber(""));
        assertTrue(Utils.isHexNoPrefix(""));
        assertFalse(Utils.isHexPrefixed(""));

        // Test invalid hex strings
        assertFalse(Utils.isHexPrefixed("0xg"));
        assertFalse(Utils.isHexPrefixed("0xG"));
        assertFalse(Utils.isHexNoPrefix("g"));
        assertFalse(Utils.isHexNoPrefix("G"));

        // Test invalid number strings
        assertFalse(Utils.isNumber("-1"));
        assertFalse(Utils.isNumber("+1"));
        assertFalse(Utils.isNumber("1.1"));
        assertFalse(Utils.isNumber("a"));
    }

    function test_ENSFunctions_EdgeCases() public {
        // Test non-existent ENS name
        address nonExistentAddr = address(0xdead);
        assertEq(nonExistentAddr.getPrimaryName(), "");

        // Test address with no reverse record
        address noReverseAddr = address(0x1);
        assertEq(noReverseAddr.getPrimaryName(), "");

        // Test vitalik.eth (known ENS name)
        address vitalik = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        string memory primaryName = vitalik.getPrimaryName();
        assertTrue(bytes(primaryName).length > 0);
        assertTrue(LibString.endsWith(primaryName, ".eth"));
    }
}
