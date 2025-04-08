# jsonapi.eth

Onchain dynamic IPLD/dag-json contenthash generator using ENS wildcard.

## Overview

jsonapi.eth is an ENS resolver that generates dynamic JSON contenthash for Ethereum token and address queries through ENS wildcard resolution, implementing the ENSIP-10 standard.

### Resolver Deployment
Mainnet: [0xF31352EDE0b4673e101D4E77dE119ab7Dd5A7251](https://etherscan.io/address/0xF31352EDE0b4673e101D4E77dE119ab7Dd5A7251)

## Features

- ENS subname wildcard resolution with ENSIP-10 support
- Query user info, balances and ERC20/721 token information
- Featured token support with ETH, WETH, and other tokens
- Dynamic JSON responses via ENS contenthash
- ERC token type detection (ERC20, ERC721)
- Address and ENS name resolution
- NFT token ID lookup
- Token price and valuation using Uniswap-v3
- Token registration system with ticker management

## Query & Response Format

### User Portfolio Query
Get user portfolio with balance information
```
<ens-name>.jsonapi.eth       # Get portfolio by ENS name
<0xaddress>.jsonapi.eth      # Get portfolio by address

Examples:
vitalik.jsonapi.eth
0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045.jsonapi.eth

Response:
{
  "ok": true,
  "time": "1739434199",
  "block": "21836278",
  "erc": 0,
  "user": {
    "address": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "name": "vitalik.eth",
    "balance": "964.458627",
    "price": "2682.386649"
  }
}
```

### Token Info Query
Get metadata, supply and price for any ERC20/721 token
```
<token>.jsonapi.eth           # Get token data by symbol
<address>.jsonapi.eth         # Get token data by address

Examples:
weth.jsonapi.eth
0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2.jsonapi.eth

Response (ERC20):
{
  "ok": true,
  "time": "1739434199",
  "block": "21836278",
  "erc": 20,
  "token": {
    "contract": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "decimals": 18,
    "marketcap": "7911248370.108695",
    "name": "Wrapped Ether",
    "price": "2682.386649",
    "supply": "2949331.847091",
    "symbol": "WETH"
  }
}

Response (ERC721):
{
  "ok": true,
  "time": "1739434199",
  "block": "21836278",
  "erc": 721,
  "token": {
    "contract": "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
    "name": "BoredApeYachtClub",
    "supply": "10000",
    "symbol": "BAYC"
  }
}
```

### User Token Balance Query
Get specific token balance and metadata for any user
```
<user>.<token>.jsonapi.eth   # Get user's token balance
<token>.<user>.jsonapi.eth   # Alternative format (both supported)

Examples:
vitalik.weth.jsonapi.eth
weth.vitalik.jsonapi.eth
0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045.0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2.jsonapi.eth

Response (ERC20):
{
  "ok": true,
  "time": "1739434199",
  "block": "21836278",
  "erc": 20,
  "token": {
    "contract": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "decimals": 18,
    "price": "2682.386649",
    "symbol": "WETH",
    "user": {
      "address": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "balance": "16.320309"
    }
  }
}

Response (ERC721):
{
  "ok": true,
  "time": "1739434199",
  "block": "21836278",
  "erc": 721,
  "token": {
    "contract": "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
    "name": "BoredApeYachtClub",
    "symbol": "BAYC",
    "supply": "10000",
    "user": {
      "address": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "balance": "1"
    }
  }
}
```

### NFT Token ID Query
Get metadata for a specific NFT token ID
```
<token-id>.<nft-contract>.jsonapi.eth

Example:
1234.bayc.jsonapi.eth
1234.0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D.jsonapi.eth

Response:
{
  "ok": true,
  "time": "1739434199",
  "block": "21836278",
  "erc": 721,
  "token": {
    "contract": "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
    "id": "1234",
    "name": "BoredApeYachtClub",
    "owner": "0xd1a770cff075f35fe5efdfc247ad1a5f7a7047a5",
    "symbol": "BAYC",
    "supply": "10000",
    "tokenURI": "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/1234"
  }
}
```

### Error Response
```json
{
  "ok": false,
  "time": "1739434199",
  "block": "21836278",
  "error": "Error Message",
  "data": ""
}
```

## Development

```shell
# Build
forge build

# Test
forge test

# Deploy
forge script script/Deploy.s.sol:DeployScript --rpc-url mainnet --private-key <key>
```

## Code Structure

### Source (`/src`)
- `Resolver.sol` - Main ENS resolver contract with ENSIP-10 implementation
- `LibJSON.sol` - DAG-JSON encoding and response formatting
- `TickerManager.sol` - Token registration and featured lists
- `Utils.sol` - Token type detection and address operations
- `ERC165.sol` - Interface detection
- `ERC173.sol` - Contract ownership
- `interfaces/` - Contract interfaces

### Tests (`/test`)
- `Resolver.t.sol` - Tests for ENS resolution and various query formats
- `Utils.t.sol` - Tests for utility functions and token operations
- `LibJSON.t.sol` - Tests for JSON encoding and formatting
- `TickerManager.t.sol` - Tests for token ticker registration
- `BillionGasReport.t.sol` - Gas optimization tests
- `ERC20.t.sol` - ERC20 token functionality tests
- `ERC721.t.sol` - ERC721 token functionality tests
- `ERC173.t.sol` - Ownership tests
- `ERC165.t.sol` - Interface detection tests

## Libraries used 
#### Solady : https://github.com/vectorized/solady
#### Check The Chain : https://github.com/z0r0z/ctc

## License

WTFPL.ETH by Namesys.eth