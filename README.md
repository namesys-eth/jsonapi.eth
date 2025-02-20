# jsonapi.eth

Onchain dynamic IPLD/dag-json contenthash generator using ENS wildcard.

## Overview

jsonapi.eth is an ENS resolver that generates dynamic JSON contenthash for Ethereum token and address queries through ENS wildcard resolution.

## Features

- Query user info, balances and ERC20/721 token information
- Featured token support with ETH, ENS Gov token and ENS domain NFT built-in
- Dynamic JSON responses via ENS contenthash
- USDC price feeds for token valuations using Uniseap-v3

## Query & Response Format

### Token Info Query
Get metadata, supply and price for any ERC20/721 token
```
<token>.jsonapi.eth           # Get token data by symbol
<address>.jsonapi.eth         # Get token data by address

Examples:
weth.jsonapi.eth
dai.jsonapi.eth
0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2.jsonapi.eth

Response (ERC20):
{
  "ok": true,
  "time": "1708482632",
  "block": "19234567",
  "result": {
    "contract": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "decimals": 18,
    "erc": 20,
    "name": "Wrapped Ether",
    "price": "3141.521234",
    "supply": "1234.567",
    "symbol": "WETH"
  }
}

Response (ERC721):
{
  "ok": true,
  "time": "1708482632",
  "block": "19234567",
  "result": {
    "contract": "0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85",
    "erc": 721,
    "name": "Ethereum Name Service",
    "supply": "N/A",
    "symbol": "ENS"
  }
}
```

### User Token Balance Query
Get specific token balance and metadata for any user
```
<user>.<token>.jsonapi.eth   # Get user's token balance
<token>.<user>.jsonapi.eth   # Alternative format

Examples:
vitalik.weth.jsonapi.eth
weth.nick.jsonapi.eth
dai.vitalik.jsonapi.eth

Response (ERC20):
{
  "ok": true,
  "time": "1708482632",
  "block": "19234567",
  "result": {
    "address": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "_balance": "1234567890000000000000",
    "balance": "1234.567890",
    "contract": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "decimals": 18,
    "ens": "vitalik.eth",
    "erc": 20,
    "name": "Wrapped Ether",
    "price": "3141.52",
    "supply": "1234.567",
    "symbol": "WETH",
    "value": "3878451.23"
  }
}

Response (ERC721):
{
  "ok": true,
  "time": "1708482632",
  "block": "19234567",
  "result": {
    "address": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "balance": "42",
    "contract": "0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85",
    "ens": "vitalik.eth",
    "erc": 721,
    "name": "Ethereum Name Service",
    "supply": "N/A",
    "symbol": "ENS"
  }
}
```

### User Portfolio Query
Get all featured token balances for any user (includes ETH, WETH, ENS by default)
```
<ens-name>.jsonapi.eth       # Get portfolio by ENS
<0xaddress>.jsonapi.eth      # Get portfolio by address

Examples:
vitalik.jsonapi.eth
nick.jsonapi.eth
0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045.jsonapi.eth

Response:
{
  "ok": true,
  "time": "1708482632",
  "block": "19234567",
  "result": {
    "address": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "name": "vitalik.eth",
    "erc20": {
      "ETH": {
        "_balance": "1234567890000000000000",
        "balance": "1234.567890",
        "contract": "N/A",
        "decimals": 18,
        "price": "3141.52",
        "symbol": "ETH",
        "totalsupply": "N/A",
        "value": "3878451.23"
      }// Other Featured ERC20.... 
    },
    "erc721": {
      "ENS": {
        "balance": "42",
        "contract": "0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85",
        "supply": "N/A",
        "symbol": "ENS"
      }
      // Other Featured ERC721....
    }
  }
}
```

### Error Response
```json
{
  "ok": false,
  "time": "1708482632",
  "block": "19234567",
  "error": "Error Message",
  "data": "0x..."
}
```

## Development

```shell
# Build
forge build

# Test
yarn test

# Deploy
forge script script/Deploy.s.sol:DeployScript --rpc-url mainnet --private-key <key>
```

## Code Structure

### Source (`/src`)
- `LibJSON.sol` - DAG-JSON encoding and response formatting
- `Resolver.sol` - Main ENS resolver contract
- `TickerManager.sol` - Token registration and featured lists
- `Utils.sol` - Token and address operations
- `ERC165.sol` - Interface detection
- `ERC173.sol` - Contract ownership
- `interfaces/` - Contract interfaces

### Tests (`/test`)
- `LibJSON.t.sol` - JSON library tests
- `Resolver.t.sol` - Resolver contract tests
- `Utils.t.sol` - Utility function tests
- `TickerManager.t.sol` - Token manager tests
- `ERC173.t.sol` - Ownership tests
- `ERC165.t.sol` - Interface tests
- `mocks/` - Mock contracts for testing

## Libraries used 
#### Solady : https://github.com/vectorized/solady
#### Check The Chain : https://github.com/z0r0z/ctc

## License

WTFPL.ETH by Namesys.eth