// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {TickerManager} from "../src/TickerManager.sol";
import "solady/utils/LibString.sol";
interface iToken {
    function symbol() external view returns (string memory);
}

contract SymbolScript is Script {
    using LibString for string;
    TickerManager public tickerManager;
    bytes32 jsonapiRoot;
    
    function check(string memory symbol, address token) public {
        string memory s = iToken(token).symbol();
        require(symbol.toCase(true).eq(s.toCase(true)), string.concat("Symbol mismatch: ", symbol, " != ", s));
        console.log(symbol);
    }
    function checkAll() public {
        for (uint256 i = 0; i < symbols.length; i++) {
            check(symbols[i], symbolToAddress[symbols[i]]);
        }
    }
    function setUp() public {
        tickerManager = TickerManager(0xF31352EDE0b4673e101D4E77dE119ab7Dd5A7251);
        jsonapiRoot = tickerManager.JSONAPIRoot();
        symbolToAddress["dai"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        symbolToAddress["weth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        symbolToAddress["usdc"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        symbolToAddress["usdt"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        symbolToAddress["bayc"] = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
        symbolToAddress["ens"] = 0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72;
        symbolToAddress["steth"] = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        symbolToAddress["cbbtc"] = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
        symbolToAddress["wbtc"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        symbolToAddress["link"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        symbolToAddress["aave"] = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
        symbolToAddress["uni"] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        symbolToAddress["shib"] = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;
        symbolToAddress["matic"] = 0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0;
        symbolToAddress["comp"] = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
        symbolToAddress["1inch"] = 0x111111111117dC0aa78b770fA6A738034120C302;
        symbolToAddress["grt"] = 0xc944E90C64B2c07662A292be6244BDf05Cda44a7;
        symbolToAddress["bat"] = 0x0D8775F648430679A709E98d2b0Cb6250d2887EF;
        symbolToAddress["ldo"] = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
        //checkAll();
    }

    function namehash(string memory _symbol) public view returns (bytes32) {
        return keccak256(abi.encodePacked(jsonapiRoot, keccak256(bytes(_symbol))));
    }
    string[] public symbols = [
        "dai", "weth", "usdc", "usdt", "bayc", "ens", "steth", "cbbtc", "wbtc", "link", "aave", "uni", "shib", "matic", "comp", "1inch", "grt", "bat", "ldo"];
    mapping(string => address) public symbolToAddress;

    function run() public {
        bytes32[] memory symbolHashes = new bytes32[](symbols.length);
        address[] memory addresses = new address[](symbols.length);
        for (uint256 i = 0; i < symbols.length; i++) {
            symbolHashes[i] = keccak256(bytes(symbols[i]));
            addresses[i] = symbolToAddress[symbols[i]];
        }
        vm.startBroadcast();
        tickerManager.setTickerBatch(addresses, symbolHashes);
        vm.stopBroadcast();
    }
}
//    ├─ [616] DSToken::DSToken(0x0000000000000000000000000000000000000000000000000000000000000000)
