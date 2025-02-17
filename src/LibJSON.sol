// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.25;

import "solady/utils/LibBytes.sol";
import "solady/utils/LibString.sol";

library LibJSON {
    using LibString for *;
    using LibBytes for *;

    function len(uint256 length) internal pure returns (bytes memory) {
        return (length < 128)
            ? abi.encodePacked(uint8(length))
            : abi.encodePacked(uint8((length % 128) + 128), uint8(length / 128));
    }

    function encodeJSON(bytes memory _data) internal pure returns (bytes memory) {
        return abi.encodePacked(hex"e30101800400", len(_data.length), _data);
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
}
