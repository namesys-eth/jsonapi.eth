// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.25;

import "solady/utils/LibBytes.sol";
import "solady/utils/LibString.sol";
import {iERC20, iERC721} from "./interfaces/IERC.sol";
import "./Utils.sol";

/**
 * @title LibJSON
 * @author WTFPL.ETH
 * @notice Library for JSON encoding and token data formatting
 * @dev Provides utilities for JSON encoding and token data formatting with gas optimizations
 */
library LibJSON {
    using LibString for *;
    using LibBytes for *;
    using Utils for *;

    error InvalidLength();

    /**
     * @notice Encode a number as a varint
     * @param _num Number to encode
     * @return _varint Encoded varint as bytes
     * only supports numbers > 0 & < 32768
     */
    function varint(uint256 _num) internal pure returns (bytes memory _varint) {
        assembly {
            /*
                if or(iszero(_num), iszero(lt(_num, 32768))) {
                    mstore(0x00, 0x947d5a84)
                    revert(0x1c, 0x04)
                }
            */
            _varint := mload(0x40)
            switch lt(_num, 128)
            case 1 {
                // For numbers < 128, just return single byte
                mstore(_varint, 1)
                mstore8(add(_varint, 0x20), _num)
                mstore(0x40, add(_varint, 0x40))
            }
            default {
                // For numbers >= 128, return two bytes
                mstore(_varint, 2)
                let quotient := div(_num, 128) // Second byte
                let remainder := mod(_num, 128) // First byte minus 0x80
                // First byte: 0x80 + remainder
                mstore8(add(_varint, 0x20), add(0x80, remainder))
                // Second byte: quotient
                mstore8(add(_varint, 0x21), quotient)
                mstore(0x40, add(_varint, 0x40))
            }
        }
    }
    /**
     * @notice Encode data as JSON with header
     * @param _data Data to encode
     * @return Encoded JSON as bytes
     */

    function encodeJSON(bytes memory _data) internal pure returns (bytes memory) {
        if (_data.length == 0) return "";
        return abi.encode(abi.encodePacked(hex"e30101800400", varint(_data.length), _data));
    }

    /**
     * @notice Format error response with data
     * @param _err Error message
     * @param _data Error data
     * @return Encoded error JSON
     */
    function toError(string memory _err, bytes memory _data) internal view returns (bytes memory) {
        return encodeJSON(
            abi.encodePacked(
                '{"ok":false,"time":',
                block.timestamp.toString(),
                ',"block":',
                block.number.toString(),
                ',"error":"',
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
        return encodeJSON(
            abi.encodePacked(
                '{"ok":false,"time":',
                block.timestamp.toString(),
                ',"block":',
                block.number.toString(),
                ',"error":"',
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
        return encodeJSON(
            abi.encodePacked(
                '{"ok":true,"time":',
                block.timestamp.toString(),
                ',"block":',
                block.number.toString(),
                ',"result":',
                _data,
                "}"
            )
        );
    }

    /**
     * @notice Format success response as text
     * @param _data Response data
     * @return Encoded success JSON as string
     */
    function toText(bytes memory _data) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                '{"ok":true,"time":',
                block.timestamp.toString(),
                ',"block":',
                block.number.toString(),
                ',"result":',
                _data,
                "}"
            )
        );
    }

    /**
     * @notice Format error response as text
     * @param _err Error message
     * @return Encoded error JSON as string
     */
    function toTextError(string memory _err) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                '{"ok":false,"time":',
                block.timestamp.toString(),
                ',"block":',
                block.number.toString(),
                ',"error":"',
                _err,
                '"}'
            )
        );
    }

    /**
     * @notice Get user info for ERC20 tokens
     * @param _owner Owner address
     * @param _token Token address
     * @return User info as JSON bytes
     */
    function getUserInfo20(address _owner, address _token) internal view returns (bytes memory) {
        (uint256 price, string memory priceStr) = _token.getPrice();
        uint8 decimals = _token.getDecimalsUint();
        uint256 balance = iERC20(_token).balanceOf(_owner);
        return abi.encodePacked(
            '{"address":"',
            _owner.toHexStringChecksummed(),
            '","_balance":"',
            balance.toString(),
            '","balance":"',
            balance.formatDecimal(decimals, 6),
            '","contract":"',
            _token.toHexStringChecksummed(),
            '","decimals":',
            decimals.toString(),
            ',"ens":"',
            _owner.getPrimaryName(),
            '","erc":20,"name":"',
            _token.getName(),
            '","price":"',
            priceStr,
            '","supply":"',
            _token.getTotalSupply20(decimals, 3),
            '","symbol":"',
            _token.getSymbol(),
            '","value":"',
            balance.calculateUSDCValue(price, decimals).formatDecimal(6, 3),
            '"}'
        );
    }

    /**
     * @notice Get user info for ERC721 tokens
     * @param _owner Owner address
     * @param _token Token address
     * @return User info as JSON bytes
     */
    function getUserInfo721(address _owner, address _token) internal view returns (bytes memory) {
        uint256 balance = iERC721(_token).balanceOf(_owner);
        return abi.encodePacked(
            '{"address":"',
            _owner.toHexStringChecksummed(),
            '","balance":"',
            balance.toString(),
            '","contract":"',
            _token.toHexStringChecksummed(),
            '","ens":"',
            _owner.getPrimaryName(),
            '","erc":721,"name":"',
            _token.getName(),
            '","supply":"',
            _token.getTotalSupply721(),
            '","symbol":"',
            _token.getSymbol(),
            '"}'
        );
    }

    /**
     * @notice Get token info for ERC20 tokens
     * @param _token Token address
     * @return Token info as JSON bytes
     */
    function getInfo20(address _token) internal view returns (bytes memory) {
        (, string memory priceStr) = _token.getPrice();
        uint8 _decimals = _token.getDecimalsUint();
        return abi.encodePacked(
            '{"contract":"',
            _token.toHexStringChecksummed(),
            '","decimals":',
            _decimals.toString(),
            ',"erc":20,"name":"',
            _token.getName(),
            '","price":"',
            priceStr,
            '","supply":"',
            _token.getTotalSupply20(_decimals, 3),
            '","symbol":"',
            _token.getSymbol(),
            '"}'
        );
    }

    /**
     * @notice Get token info for ERC721 tokens
     * @param _token Token address
     * @return Token info as JSON bytes
     */
    function getInfo721(address _token) internal view returns (bytes memory) {
        return abi.encodePacked(
            '{"contract":"',
            _token.toHexStringChecksummed(),
            '","erc":721,"name":"',
            _token.getName(),
            '","supply":"',
            _token.getTotalSupply721(),
            '","symbol":"',
            _token.getSymbol(),
            '"}'
        );
    }

    function getInfoByTokenId(address _token, uint256 _tokenId) internal view returns (bytes memory) {
        return abi.encodePacked(
            '{"contract":"',
            _token.toHexStringChecksummed(),
            '","erc":721,"name":"',
            _token.getName(),
            '","owner":"',
            _token.getNFTOwner(_tokenId),
            '","supply":"',
            _token.getTotalSupply721(),
            '","symbol":"',
            _token.getSymbol(),
            '","tokenId":"',
            _tokenId.toString(),
            '","tokenURI":"',
            _token.getTokenURI(_tokenId),
            '"}'
        );
    }
    /**
     * @notice Get ETH featured info
     * @param _owner Owner address
     * @return Featured ETH info as JSON bytes
     */

    function getETHFeatured(address _owner) internal view returns (bytes memory) {
        uint256 _bal = _owner.balance;
        (uint256 _price,) = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).getPrice(); // WETH price
        return abi.encodePacked(
            '"ETH":{"_balance":"',
            _bal.toString(),
            '","balance":"',
            _bal.formatDecimal(18, 6),
            '","contract":"N/A","decimals":18,"price":"',
            _price.formatDecimal(6, 6),
            '","symbol":"ETH","totalsupply":"N/A","value":"',
            _bal.calculateUSDCValue(_price, 18).formatDecimal(6, 6),
            '"}'
        );
    }

    /**
     * @notice Get ENS featured info
     * @param _owner Owner address
     * @return Featured ENS info as JSON bytes
     */
    function getENSFeatured(address _owner) internal view returns (bytes memory) {
        uint256 _bal = Utils.ENS721.balanceOf(_owner);
        return abi.encodePacked(
            '"ENS":{"balance":"',
            _bal.toString(),
            '","contract":"',
            address(Utils.ENS721).toHexStringChecksummed(),
            '","supply":"N/A","symbol":"ENS"}'
        );
    }

    /**
     * @notice Get featured info for ERC721 tokens
     * @param _token Token address
     * @param _balance Token balance
     * @param _symbol Token symbol
     * @return Featured token info as JSON bytes
     */
    function getFeatured721(address _token, uint256 _balance, string memory _symbol)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            '"',
            _symbol,
            '":{"balance":"',
            _balance.toString(),
            '","contract":"',
            _token.toHexStringChecksummed(),
            '","supply":"',
            _token.getTotalSupply721(),
            '","symbol":"',
            _symbol,
            '"},'
        );
    }

    /**
     * @notice Get featured info for ERC20 tokens
     * @param _decimals Token decimals
     * @param _token Token address
     * @param _balance Token balance
     * @param _symbol Token symbol
     * @return Featured token info as JSON bytes
     */
    function getFeatured20(uint8 _decimals, address _token, uint256 _balance, string memory _symbol)
        internal
        view
        returns (bytes memory)
    {
        (uint256 _price, string memory priceStr) = address(_token).getPrice();
        return abi.encodePacked(
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
            priceStr,
            '","supply":"',
            iERC20(_token).totalSupply().formatDecimal(_decimals, 3),
            '","symbol":"',
            _symbol,
            '","value":"',
            _balance.calculateUSDCValue(_price, _decimals).formatDecimal(6, 3),
            '"},'
        );
    }
}
