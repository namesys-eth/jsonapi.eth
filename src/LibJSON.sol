// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.25;

import "solady/utils/LibBytes.sol";
import "solady/utils/LibString.sol";
import "./Interface.sol";
import "./Utils.sol";

library LibJSON {
    using LibString for *;
    using LibBytes for *;
    using Utils for *;

    function varint(uint256 length) internal pure returns (bytes memory) {
        return (length < 128)
            ? abi.encodePacked(uint8(length))
            : abi.encodePacked(uint8((length % 128) + 128), uint8(length / 128));
    }

    function encodeJSON(bytes memory _data) internal pure returns (bytes memory) {
        return abi.encodePacked(hex"e30101800400", varint(_data.length), _data);
    }

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

    function toJSON(bytes memory _data) internal view returns (bytes memory) {
        return encodeJSON(
            abi.encodePacked(
                '{"ok":true,"time":',
                block.timestamp.toString(),
                ',"block":',
                block.number.toString(),
                ',"result":{',
                _data,
                "}}"
            )
        );
    }

    function toText(bytes memory _data) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                '{"ok":true,"time":',
                block.timestamp.toString(),
                ',"block":',
                block.number.toString(),
                ',"result":{',
                _data,
                '"}'
            )
        );
    }

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

    /// @notice Get user info for erc20 tokens
    /// @param _owner Owner address
    /// @param _token Token address
    /// @return bytes memory User info
    /// @dev <0xaddr|domain>.<0xerc20|symbol>.jsonapi.eth

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
            '","decimals":"',
            decimals.toString(),
            '","ens":"',
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
            balance.calculateUSDCValue(price, decimals),
            '"}'
        );
    }

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

    function getETHFeatured(address _owner) internal view returns (bytes memory) {
        uint256 _bal = _owner.balance;
        (uint256 _price,) = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).getPrice(); // WETH price
        return abi.encodePacked(
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

    function getENSFeatured(address _owner) internal view returns (bytes memory) {
        uint256 _bal = Utils.ENS721.balanceOf(_owner);
        return abi.encodePacked(
            '"ENS":{"balance":"',
            _bal.toString(),
            '","contract":"',
            _owner.toHexStringChecksummed(),
            '","supply":"N/A","symbol":"ENS"}'
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
            '","supply":"',
            _token.getTotalSupply721(),
            '","symbol":"',
            _symbol,
            '"},'
        );
    }

    function getFeatured20(uint8 _decimals, address _token, uint256 _balance, string memory _symbol)
        internal
        view
        returns (bytes memory _featured)
    {
        (uint256 _price, string memory priceStr) = address(_token).getPrice();
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
            priceStr,
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
