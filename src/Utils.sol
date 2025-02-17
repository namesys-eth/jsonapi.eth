// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import "./Interface.sol";
import {LibString} from "solady/utils/LibString.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";

library Utils {
    using LibString for *;

    iCheckTheChainEthereum internal constant CTC = iCheckTheChainEthereum(0x0000000000cDC1F8d393415455E382c30FBc0a84);

    iENS internal constant ENS = iENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    iERC721 internal constant ENS721 = iERC721(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    address internal constant ENSWrapper = 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401;

    /// @dev Allowed ASCII Hex (0-9, a-f) characters for 7-bit ASCII strings.
    uint128 internal constant ASCII_HEX_MASK_NO_PREFIX = 9982748476797594485687712743424;
    /// @dev Allowed ASCII Number 0-9 characters for 7-bit ASCII strings.
    uint128 internal constant ASCII_NUMBER_MASK = 287948901175001088;
    /// @dev Allowed ASCII Hex (0-9, a-f & "0x") characters for 7-bit ASCII strings.
    uint128 internal constant ASCII_HEX_MASK_PREFIXED = 1329237978533392670498292747993088000;

    error NotANumber();
    error OddHexLength();

    /// @notice Converts a prefixed LOWERCASE hex string to bytes.
    /// @param input The input string to convert.
    /// @return result The converted bytes.
    /// @dev REQUIREMENTS:
    /// - Input must be a valid hex string with "0x" prefix
    /// - Input length must be even (2 hex chars = 1 byte)
    /// - Only lowercase hex chars allowed (0-9, a-f)
    function prefixedHexStringToBytes(bytes memory input) internal pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let len := mload(input)
            let outLen := shr(1, sub(len, 2)) // (len - 2) / 2

            // Allocate memory
            result := mload(0x40)
            mstore(result, outLen)
            let nextPtr := add(add(result, 0x20), outLen)
            mstore(0x40, and(add(nextPtr, 31), not(31)))

            // Zero out memory
            let lastWord := and(sub(nextPtr, 1), not(31))
            mstore(lastWord, 0)

            // Skip "0x" prefix and process 2 hex chars at a time
            let inPtr := add(input, 0x22)
            let outPtr := add(result, 0x20)

            for { let i := 0 } lt(i, outLen) { i := add(i, 1) } {
                let byte1 := byte(0, mload(inPtr))
                let byte2 := byte(0, mload(add(inPtr, 1)))

                byte1 := sub(byte1, add(48, mul(39, gt(byte1, 57))))
                byte2 := sub(byte2, add(48, mul(39, gt(byte2, 57))))

                mstore8(add(outPtr, i), or(shl(4, byte1), byte2))
                inPtr := add(inPtr, 2)
            }
        }
    }

    /**
     * @dev Converts a string representation of a number to uint256.
     * @param s The byte array containing the string representation of a number.
     * @return result The uint256 value of the input.
     * @dev Warning: Does not validate input. Caller must ensure string contains only valid digits.
     */
    function stringToUint(string memory s) public pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let end := add(mload(s), add(s, 0x20)) // combine length calc with ptr
            for { let ptr := add(s, 0x20) } lt(ptr, end) { ptr := add(ptr, 1) } {
                result := add(mul(result, 10), sub(byte(0, mload(ptr)), 48))
            }
        }
    }

    /// @notice Checks if the input is a valid address.
    /// @dev Valid addresses are 42 bytes long and prefixed with "0x".
    /// only supports lowercase hex strings, as it's auto normalized by ENS
    /// @param data The input bytes to check.
    /// @return result True if the input is a valid address, false otherwise.
    function isAddress(bytes memory data) internal pure returns (bool) {
        return data.length == 42 && string(data).startsWith("0x") && string(data).is7BitASCII(ASCII_HEX_MASK_PREFIXED);
    }

    /// @notice Gets the name of the contract.
    /// @param addr The address of the contract to get the name of.
    /// @return name The name of the contract.
    function getName(address addr) internal view returns (string memory) {
        try iERC20(addr).name() returns (string memory name) {
            return name;
        } catch {
            return "N/A";
        }
    }

    function getSymbol(address addr) internal view returns (string memory) {
        try iERC20(addr).symbol() returns (string memory symbol) {
            return symbol;
        } catch {
            return "N/A";
        }
    }

    function getDecimals(address _contract) internal view returns (string memory) {
        try iERC20(_contract).decimals() returns (uint8 decimals) {
            return LibString.toString(decimals);
        } catch {
            return "0";
        }
    }

    function getTotalSupply(address _contract) internal view returns (string memory) {
        try iERC20(_contract).totalSupply() returns (uint256 totalSupply) {
            return totalSupply.toString();
        } catch {
            return "0";
        }
    }

    function getBalance(address _contract, address _account) internal view returns (string memory) {
        try iERC20(_contract).balanceOf(_account) returns (uint256 balance) {
            return balance.toString();
        } catch {
            return "0";
        }
    }

    function getOwner(address _contract, uint256 _tokenId) internal view returns (string memory) {
        try iERC721(_contract).ownerOf(_tokenId) returns (address owner) {
            return LibString.toHexString(owner);
        } catch {
            return "0x0000000000000000000000000000000000000000";
        }
    }

    function getTokenURI(address _contract, uint256 _tokenId) internal view returns (string memory) {
        try iERC721Metadata(_contract).tokenURI(_tokenId) returns (string memory tokenURI) {
            if (tokenURI.startsWith("data:")) {
                if (tokenURI.startsWith("data:application/json")) {
                    return tokenURI.escapeJSON();
                } else if (tokenURI.startsWith("data:text/plain,{")) {
                    // some old NFTs return plain text data URI
                    return tokenURI.escapeJSON();
                }
                // assume data uri is base64 encoded
            } else if (tokenURI.contains('"')) {
                return tokenURI.escapeHTML();
            }
            return tokenURI;
        } catch {
            return "";
        }
    }

    function getContractURI(address _contract) internal view returns (string memory) {
        try iERC721ContractMetadata(_contract).contractURI() returns (string memory contractURI) {
            if (contractURI.startsWith("data:application/json")) {
                return contractURI.escapeJSON();
            } else if (contractURI.contains('"')) {
                return contractURI.escapeHTML();
            }
            return contractURI;
        } catch {
            return "";
        }
    }

    iENSReverse internal constant ENSReverse = iENSReverse(0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb);

    function getPrimaryName(address _addr) internal view returns (string memory _name) {
        bytes32 node = ENSReverse.node(_addr);
        address reverseResolver = ENSReverse.resolver(node);
        if (reverseResolver != address(0)) {
            try iResolver(reverseResolver).name(node) returns (string memory name) {
                return name; // domain.eth
            } catch {}
        }
    }

    function isERC721(address addr) internal view returns (bool) {
        //if (addr.code.length == 0) return false;
        try iERC165(addr).supportsInterface(type(iERC721).interfaceId) returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }

    function isERC20(address addr) internal view returns (bool) {
        //if (addr.code.length == 0) return false;
        try iERC20(addr).decimals() returns (uint8) {
            return true;
        } catch {
            return false;
        }
    }

    function getERCType(address addr) internal view returns (uint256) {
        if (addr.code.length == 0) return 0;
        return isERC721(addr) ? 721 : isERC20(addr) ? 20 : 0;
    }

    function getPrice(address _token) internal view returns (uint256, string memory) {
        try CTC.checkPrice(_token) returns (uint256 _price, string memory _priceStr) {
            return (_price, _priceStr);
        } catch {
            try CTC.checkPriceInETHToUSDC(_token) returns (uint256 _price, string memory _priceStr) {
                return (_price, _priceStr);
            } catch {
                return (0, "");
            }
        }
    }

    function getInfo20(address _token) internal view returns (bytes memory) {
        (, string memory priceStr) = getPrice(_token);
        return abi.encodePacked(
            '"contract":"',
            LibString.toHexStringChecksummed(_token),
            '","decimals":',
            getDecimals(_token),
            ',"erc":20,"name":"',
            getName(_token),
            '","price":"',
            priceStr,
            ' USDC","supply":"',
            getTotalSupply(_token),
            '","symbol":"',
            getSymbol(_token),
            '"'
        );
    }

    function getInfo721(address _token) internal view returns (bytes memory) {
        return abi.encodePacked(
            '"contract":"',
            LibString.toHexStringChecksummed(_token),
            '","erc":721,"name":"',
            getName(_token),
            '","supply":"',
            getTotalSupply(_token),
            '","symbol":"',
            getSymbol(_token),
            '"'
        );
    }

    function getUserInfo20(address _owner, address _token) internal view returns (bytes memory) {
        (uint256 price, string memory priceStr) = getPrice(_token);
        uint256 balance = iERC20(_token).balanceOf(_owner);
        return abi.encodePacked(
            '"balance":"',
            LibString.toString(balance),
            '","contract":"',
            LibString.toHexStringChecksummed(_token),
            '","erc":20,"name":"',
            getName(_token),
            '","price":"',
            priceStr,
            '", "value":"',
            LibString.toString((balance * price) / 10 ** 6), // 6 decimals in USDC
            '", "supply":"',
            getTotalSupply(_token),
            '"'
        );
    }

    function getUserInfo721(address _owner, address _token) internal view returns (bytes memory) {
        return abi.encodePacked('"balance":"', getBalance(_token, _owner), '"');
    }

    function checkInterface(address _addr, bytes4 _selector) internal view returns (bool) {
        if (_addr.code.length == 0) return false;
        try iERC165(_addr).supportsInterface(_selector) returns (bool ok) {
            return ok;
        } catch {
            return false;
        }
    }

    function getENSAddress(address _resolver, bytes32 node) internal view returns (address _addr) {
        if (checkInterface(_resolver, iResolver.addr.selector)) {
            try iResolver(_resolver).addr(node) returns (address payable addr) {
                return addr;
            } catch {
                return address(0);
            }
        }
    }

    function isNumber(string memory s) internal pure returns (bool) {
        return LibString.is7BitASCII(s, ASCII_NUMBER_MASK);
    }

    function isHexPrefixed(string memory s) internal pure returns (bool) {
        return LibString.startsWith(s, "0x") && LibString.is7BitASCII(s, ASCII_HEX_MASK_PREFIXED);
    }

    function isHexNoPrefix(string memory s) internal pure returns (bool) {
        return LibString.is7BitASCII(s, ASCII_HEX_MASK_NO_PREFIX);
    }

    /// @notice Calculates total value in USDC (6 decimals) from token balance and price
    /// @param _balance The token balance in token decimals
    /// @param price The price in USDC (6 decimals)
    /// @param decimals The token decimals
    /// @return value The total value in USDC (6 decimals)
    function calculateUSDCValue(uint256 _balance, uint256 price, uint8 decimals)
        internal
        pure
        returns (uint256 value)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Handle zero cases first
            if or(iszero(_balance), iszero(price)) {
                //value := 0
                return(0, 0)
            }

            switch gt(decimals, 6)
            case 1 {
                // If decimals > 6 (like ETH's 18 decimals)
                //let scaledProduct := mul(_balance, price)
                //let divisor := exp(10, decimals)  // First divide by token decimals
                value := div(mul(_balance, price), exp(10, decimals)) // Result is in USDC's 6 decimals
            }
            case 0 {
                switch lt(decimals, 6)
                case 1 {
                    // If decimals < 6
                    //let multiplier := exp(10, sub(6, decimals))
                    //value := div(mul(_balance, price), 1000000)  // First get the raw value
                    value := mul(div(mul(_balance, price), 1000000), exp(10, sub(6, decimals))) // Then scale up to 6 decimals
                }
                default {
                    // If decimals == 6
                    value := div(mul(_balance, price), 1000000)
                }
            }
        }
    }

    error BadPrecision();

    /// @notice Formats USDC value (6 decimals) to string
    /// @param value Token units
    /// @param decimals The token decimals
    /// @return result The formatted string like "999.999"

    function formatDecimal(
        uint256 value, // The value to format
        uint256 decimals, // Number of decimals in the input value (e.g., 18 for ETH)
        uint256 precision // How many decimal places to show (must be <= decimals)
    ) public pure returns (string memory result) {
        if (precision > decimals) {
            return value.toString();
        }
        /// @solidity memory-safe-assembly
        assembly {
            // Revert if precision > decimals
            /*if gt(precision, decimals) {
                mstore(0x00, 0x0d5a0d37) // BadPrecision()
                revert(0x1c, 0x04)
            }*/
            // no revertss, don't want to break whole lookup process

            // Split value into whole and decimal parts
            //let divisor := exp(10, decimals)
            let whole := div(value, exp(10, decimals))
            let decimalValue := div(mod(value, exp(10, decimals)), exp(10, sub(decimals, precision)))

            // Calculate decimal length (will be 0 if decimal part is 0)
            let decimalLength := mul(precision, iszero(iszero(decimalValue)))

            // Count digits in whole number (minimum 1 digit for zero)
            let wholeLength := 0
            for { let temp := whole } gt(temp, 0) {} {
                wholeLength := add(wholeLength, 1)
                temp := div(temp, 10)
            }
            wholeLength := add(wholeLength, iszero(wholeLength))

            // Total length = whole digits + decimal point (if needed) + decimal digits
            let totalLength :=
                add(
                    wholeLength,
                    add(
                        mul(iszero(iszero(decimalLength)), 1), // Add 1 for decimal point if we have decimals
                        decimalLength
                    )
                )

            // Setup result string in memory
            result := mload(0x40)
            mstore(result, totalLength)
            mstore(0x40, add(add(result, 32), totalLength))

            // Write whole number digits from right to left
            let ptr := add(result, 32)
            for { let i := sub(wholeLength, 1) } gt(i, 0) { i := sub(i, 1) } {
                mstore8(add(ptr, i), add(48, mod(whole, 10)))
                whole := div(whole, 10)
            }
            mstore8(ptr, add(48, mod(whole, 10)))

            // Write decimal point and decimal digits if needed
            if gt(decimalLength, 0) {
                mstore8(add(ptr, wholeLength), 0x2e) // . (decimal point)
                let decimalPtr := add(ptr, add(wholeLength, 1))
                // Write decimal digits from right to left
                for { let i := 0 } lt(i, decimalLength) { i := add(i, 1) } {
                    mstore8(add(decimalPtr, sub(sub(decimalLength, 1), i)), add(48, mod(decimalValue, 10)))
                    decimalValue := div(decimalValue, 10)
                }
            }
        }
    }
}
