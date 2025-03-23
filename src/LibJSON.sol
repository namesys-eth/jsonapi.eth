// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.25;

/**
 * @title LibJSON
 * @author WTFPL.ETH
 * @notice Library for JSON encoding and token data formatting
 * @dev Provides utilities for JSON encoding and token data formatting
 */
import "solady/utils/LibBytes.sol";
import "solady/utils/LibString.sol";
import {iERC20, iERC721} from "./interfaces/IERC.sol";
import "./Utils.sol";
import "solady/utils/DynamicBufferLib.sol";

library LibJSON {
    using LibString for *;
    using LibBytes for *;
    using Utils for *;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    bytes public constant IPLD_DAG_JSON = hex"e30101800400";

    /**
     * @notice Encode a number as a varint
     * @param _num Number to encode
     * @return _varint Encoded varint as bytes
     * @dev only supports numbers >0 & < 32768
     */
    function varint(uint256 _num) internal pure returns (bytes memory _varint) {
        assembly ("memory-safe") {
            _varint := mload(0x40)
            switch lt(_num, 128)
            case 1 {
                mstore(_varint, 1)
                mstore8(add(_varint, 0x20), _num)
                mstore(0x40, add(_varint, 0x40))
            }
            default {
                mstore(_varint, 2)
                mstore8(add(_varint, 0x20), add(0x80, mod(_num, 128)))
                mstore8(add(_varint, 0x21), div(_num, 128))
                mstore(0x40, add(_varint, 0x40))
            }
        }
    }

    /**
     * @notice Encode data as JSON with header for ENS contenthash
     * @param _data Data to encode
     * @return Encoded JSON as bytes
     */
    function encodeContentHash(bytes memory _data) internal pure returns (bytes memory) {
        return abi.encode(abi.encodePacked(IPLD_DAG_JSON, varint(_data.length), _data));
    }

    /**
     * @notice Format error response with data
     * @param _err Error message
     * @param _data Error data
     * @return Encoded error JSON
     */
    function toError(string memory _err, bytes memory _data) internal view returns (bytes memory) {
        return encodeContentHash(
            abi.encodePacked(
                '{"ok":false,"time":"',
                block.timestamp.toString(),
                '","block":"',
                block.number.toString(),
                '","error":"',
                _err,
                '","data":"',
                _data.toHexString(),
                '"}'
            )
        );
    }

    /**
     * @notice Format error response without data
     * @param _err Error message
     * @return Encoded error JSON
     */
    function toError(string memory _err) internal view returns (bytes memory) {
        return encodeContentHash(
            abi.encodePacked(
                '{"ok":false,"time":"',
                block.timestamp.toString(),
                '","block":"',
                block.number.toString(),
                '","error":"',
                _err,
                '","data":""}'
            )
        );
    }

    /**
     * @notice Format success response
     * @param _data Response data
     * @return Encoded success JSON
     */
    function toJSON(bytes memory _data) internal view returns (bytes memory) {
        //forgefmt: disable-next-item
        return encodeContentHash(abi.encodePacked(
            '{"ok":true,"time":"',
                block.timestamp.toString(),
                '","block":"',
                block.number.toString(),
                '",',
                _data,
                "}"
            )
        );
    }

    /**
     * @notice Get user info for ERC20 tokens
     * @param _owner Owner address
     * @param erc20 ERC20 token Interface
     * @return User info as JSON bytes
     */
    function erc20UserInfo(address _owner, iERC20 erc20) internal view returns (bytes memory) {
        (, string memory priceStr) = address(erc20).checkTheChain();
        uint8 decimals = erc20.decimals();
        uint256 balance = erc20.balanceOf(_owner);
        return abi.encodePacked(
            '"erc":20,"token":{"contract":"',
            address(erc20).toHexStringChecksummed(),
            '","decimals":',
            decimals.toString(),
            ',"price":"',
            priceStr,
            '","symbol":"',
            erc20.symbol(),
            '","user":{"address":"',
            _owner.toHexStringChecksummed(),
            '","balance":"',
            balance.toDecimal(decimals),
            '"}}'
        );
    }

    /**
     * @notice Get user info for ERC721 tokens
     * @param _owner Owner address
     * @param _token Token address
     * @return User info as JSON bytes
     */
    function erc721UserInfo(address _owner, address _token) internal view returns (bytes memory) {
        uint256 balance = iERC721(_token).balanceOf(_owner);
        return abi.encodePacked(
            '"erc":721,"token":{"contract":"',
            _token.toHexStringChecksummed(),
            '","name":"',
            _token.getName(),
            '","supply":"',
            _token.getTotalSupply721(),
            '","symbol":"',
            _token.getSymbol(),
            '","user":{"address":"',
            _owner.toHexStringChecksummed(),
            '","balance":"',
            balance.toString(),
            '"}}'
        );
    }

    /**
     * @notice Get token info for ERC20 tokens
     * @param erc20 ERC20 token Interface
     * @return Token info as JSON bytes
     */
    function erc20Info(iERC20 erc20) internal view returns (bytes memory) {
        (uint256 _price, string memory priceStr) = address(erc20).checkTheChain();
        uint8 decimals = erc20.decimals();
        uint256 supply = erc20.totalSupply();

        return abi.encodePacked(
            '"erc":20,"token":{"contract":"',
            address(erc20).toHexStringChecksummed(),
            '","decimals":',
            decimals.toString(),
            ',"marketcap":"',
            supply.toUSDC(_price, decimals).toDecimal(6),
            '","name":"',
            erc20.name(),
            '","price":"',
            priceStr,
            '","supply":"',
            supply.toDecimal(decimals),
            '","symbol":"',
            erc20.symbol(),
            '"}'
        );
    }

    /**
     * @notice Get token info for ERC721 tokens
     * @param _token Token address
     * @return Token info as JSON bytes
     */
    function erc721Info(address _token) internal view returns (bytes memory) {
        return abi.encodePacked(
            '"erc":721,"token":{"contract":"',
            _token.toHexStringChecksummed(),
            '","name":"',
            _token.getName(),
            '","supply":"',
            _token.getTotalSupply721(),
            '","symbol":"',
            _token.getSymbol(),
            '"}'
        );
    }

    /**
     * @notice Get information about a specific NFT token ID
     * @param _token Token address
     * @param _tokenId Token ID
     * @return Token info as JSON bytes
     */
    function getInfoByTokenId(address _token, uint256 _tokenId) internal view returns (bytes memory) {
        return abi.encodePacked(
            '"erc":721,"token":{"contract":"',
            _token.toHexStringChecksummed(),
            '","id":"',
            _tokenId.toString(),
            '","name":"',
            _token.getName(),
            '","owner":"',
            _token.getNFTOwner(_tokenId),
            '","symbol":"',
            _token.getSymbol(),
            '","supply":"',
            _token.getTotalSupply721(),
            '","tokenURI":"',
            _token.getTokenURI(_tokenId),
            '"}'
        );
    }

    /**
     * @notice Get user info
     * @param _user Address to get info for
     * @return result Response in JSON format
     */
    function getUserInfo(address _user) internal view returns (bytes memory) {
        uint256 _balance = _user.balance;
        (uint256 _price,) = WETH.checkTheChain(); // WETH price
        return abi.encodePacked(
            '"erc":0,"user":{"address":"',
            _user.toHexStringChecksummed(),
            '","name":"',
            _user.getPrimaryName(),
            '","balance":"',
            _balance.toDecimal(18),
            '","price":"',
            _price.toDecimal(6),
            '"}'
        );
    }
}
