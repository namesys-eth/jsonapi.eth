// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import {iERC20, iERC721, iERC721Metadata, iERC165} from "./interfaces/IERC.sol";
import {iENS, iENSReverse, iResolver} from "./interfaces/IENS.sol";
import {iCheckTheChainEthereum} from "./interfaces/ICheckTheChain.sol";
import {LibString} from "solady/utils/LibString.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";
import {LibJSON} from "./LibJSON.sol";

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
    error InvalidDecimals();
    error ContractNotFound();
    error NotERC721Metadata();
    error InvalidInput();

    /**
     * @notice Convert hex string to bytes
     * @param input Hex string with "0x" prefix
     * @return result Converted bytes
     * @dev Input must be even length, lowercase (0-9,a-f)
     */
    function prefixedHexStringToBytes(bytes memory input) internal pure returns (bytes memory result) {
        if (input.length < 2) revert InvalidInput();
        if (!isHexPrefixed(string(input))) revert InvalidInput();

        /// @solidity memory-safe-assembly
        assembly {
            let outLen := shr(1, sub(mload(input), 2)) // (len - 2) / 2

            result := add(mload(0x40), 0x20)
            mstore(result, outLen)
            let ptr := add(result, 0x20)
            let end := add(ptr, outLen)
            mstore(0x40, and(add(end, 31), not(31)))

            // Process 2 hex chars at a time from left to right
            let inPtr := add(input, 0x22) // Skip "0x" prefix
            for {} lt(ptr, end) {} {
                let byte1 := byte(0, mload(inPtr))
                let byte2 := byte(0, mload(add(inPtr, 1)))
                mstore8(
                    ptr,
                    or(shl(4, sub(byte1, add(48, mul(39, gt(byte1, 57))))), sub(byte2, add(48, mul(39, gt(byte2, 57)))))
                )
                ptr := add(ptr, 1)
                inPtr := add(inPtr, 2)
            }
            mstore(end, 0) // Zeroize the slot after
        }
    }

    /**
     * @dev Convert string to uint256
     * @param s String containing only digits
     * @return result Parsed number
     */
    function stringToUint(string memory s) internal pure returns (uint256 result) {
        if (!isNumber(s)) revert NotANumber();
        /// @solidity memory-safe-assembly
        assembly {
            let end := add(mload(s), add(s, 0x20)) // combine length calc with ptr
            for { let ptr := add(s, 0x20) } lt(ptr, end) { ptr := add(ptr, 1) } {
                result := add(mul(result, 10), sub(byte(0, mload(ptr)), 48))
            }
        }
    }

    /**
     * @notice Check if input is valid ETH address
     * @param data Input bytes to check
     * @return True if valid address
     */
    function isAddress(bytes memory data) internal pure returns (bool) {
        return data.length == 42 && string(data).startsWith("0x") && string(data).is7BitASCII(ASCII_HEX_MASK_PREFIXED);
    }

    /**
     * @notice Get contract name
     * @param addr Contract address
     * @return Contract name or "N/A"
     */
    function getName(address addr) internal view returns (string memory) {
        try iERC20(addr).name() returns (string memory name) {
            return name;
        } catch {
            return "N/A";
        }
    }

    /**
     * @notice Get token symbol
     * @param addr Token address
     * @return Symbol or "N/A"
     */
    function getSymbol(address addr) internal view returns (string memory) {
        try iERC20(addr).symbol() returns (string memory symbol) {
            return symbol;
        } catch {
            return "N/A";
        }
    }

    /**
     * @notice Get token decimals
     * @param _contract Token address
     * @return Decimals as string
     */
    function getDecimals(address _contract) internal view returns (string memory) {
        try iERC20(_contract).decimals() returns (uint8 decimals) {
            return decimals.toString();
        } catch {
            return "0";
        }
    }

    /**
     * @notice Get token decimals
     * @param _contract Token address
     * @return Decimals as uint
     */
    function getDecimalsUint(address _contract) internal view returns (uint8) {
        try iERC20(_contract).decimals() returns (uint8 decimals) {
            return decimals;
        } catch {
            return 0;
        }
    }

    /**
     * @notice Get token total supply
     * @param _contract Token address
     * @return Total supply as string
     */
    function getTotalSupply721(address _contract) internal view returns (string memory) {
        try iERC20(_contract).totalSupply() returns (uint256 totalSupply) {
            return totalSupply.toString();
        } catch {
            return "0";
        }
    }

    /**
     * @notice Get token total supply
     * @param _contract Token address
     * @param _decimals Token decimals
     * @param _precision Precision for formatting
     * @return Total supply as string
     */
    function getTotalSupply20(address _contract, uint8 _decimals, uint8 _precision)
        internal
        view
        returns (string memory)
    {
        try iERC20(_contract).totalSupply() returns (uint256 totalSupply) {
            return formatDecimal(totalSupply, _decimals, _precision > _decimals ? _precision - _decimals : _precision);
        } catch {
            return "0";
        }
    }

    /**
     * @notice Get token balance
     * @param _contract Token address
     * @param _account Account to check
     * @param _decimals Token decimals
     * @return Balance as string
     */
    function getBalance20(address _contract, address _account, uint8 _decimals) internal view returns (string memory) {
        try iERC20(_contract).balanceOf(_account) returns (uint256 balance) {
            return formatDecimal(balance, _decimals, 6);
        } catch {
            return "0";
        }
    }

    /**
     * @notice Get token balance
     * @param _contract Token address
     * @param _account Account to check
     * @return Balance as string
     */
    function getBalance721(address _contract, address _account) internal view returns (string memory) {
        try iERC20(_contract).balanceOf(_account) returns (uint256 balance) {
            return balance.toString();
        } catch {
            return "0";
        }
    }

    /**
     * @notice Get NFT owner
     * @param _contract NFT address
     * @param _tokenId Token ID
     * @return Owner address as hex
     */
    function getOwner(address _contract, uint256 _tokenId) internal view returns (string memory) {
        try iERC721(_contract).ownerOf(_tokenId) returns (address owner) {
            return LibString.toHexString(owner);
        } catch {
            return "0x0000000000000000000000000000000000000000";
        }
    }

    /**
     * @notice Get NFT token URI
     * @param _contract NFT address
     * @param _tokenId Token ID
     * @return Token URI
     */
    function getTokenURI(address _contract, uint256 _tokenId) internal view returns (string memory) {
        try iERC721Metadata(_contract).tokenURI(_tokenId) returns (string memory tokenURI) {
            if (bytes(tokenURI).length == 0) return "";
            if (tokenURI.startsWith("data:")) {
                if (tokenURI.startsWith("data:application/json,")) {
                    return tokenURI.escapeJSON();
                } else if (tokenURI.startsWith("data:text/plain,")) {
                    return tokenURI.escapeJSON();
                }
                // Return as-is for other data URIs (e.g. base64)
                return tokenURI;
            }

            // Handle URIs with quotes that need escaping
            if (tokenURI.contains('"')) {
                return tokenURI.escapeHTML();
            }

            return tokenURI;
        } catch {
            return "";
        }
    }

    iENSReverse internal constant ENSReverse = iENSReverse(0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb);

    /**
     * @notice Get ENS reverse record
     * @param _addr Address to lookup
     * @return _name Primary ENS name
     */
    function getPrimaryName(address _addr) internal view returns (string memory _name) {
        if (_addr == address(0)) return "";
        bytes32 revNode = ENSReverse.node(_addr);
        address reverseResolver = ENS.resolver(revNode);
        if (reverseResolver != address(0)) {
            try iResolver(reverseResolver).name(revNode) returns (string memory name) {
                return name;
            } catch {}
        }
    }

    /**
     * @notice Check if contract is ERC721
     * @param addr Contract address
     * @return True if ERC721
     */
    function isERC721(address addr) private view returns (bool) {
        try iERC165(addr).supportsInterface(type(iERC721).interfaceId) returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }

    /**
     * @notice Check if contract is ERC20
     * @param addr Contract address
     * @return True if ERC20
     */
    function isERC20(address addr) private view returns (bool) {
        try iERC20(addr).decimals() returns (uint8) {
            return true;
        } catch {
            return false;
        }
    }

    /**
     * @notice Get contract type
     * @param addr Contract address
     * @return 721, 20 or 0
     */
    function getERCType(address addr) internal view returns (uint256) {
        if (addr.code.length == 0) return 0;
        return isERC721(addr) ? 721 : isERC20(addr) ? 20 : 0;
    }

    /**
     * @notice Get token price in USDC
     * @param _token Token address
     * @return Price and formatted string
     */
    function getPrice(address _token) internal view returns (uint256, string memory) {
        if (_token == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) {
            return (1e6, "1"); // hardcode USDC price to 1
        }
        if (_token.code.length == 0) revert ContractNotFound();
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

    /**
     * @notice Check interface support
     * @param _addr Contract address
     * @param _selector Interface ID
     * @return True if supported
     */
    function checkInterface(address _addr, bytes4 _selector) internal view returns (bool) {
        if (_addr.code.length == 0) return false;
        try iERC165(_addr).supportsInterface(_selector) returns (bool ok) {
            return ok;
        } catch {
            return false;
        }
    }

    /**
     * @notice Get ENS address record
     * @param _resolver Resolver address
     * @param node ENS node
     * @return _addr Resolved address
     */
    function getENSAddress(address _resolver, bytes32 node) internal view returns (address _addr) {
        if (_resolver.code.length == 0) return address(0);
        if (checkInterface(_resolver, iResolver.addr.selector)) {
            try iResolver(_resolver).addr(node) returns (address payable addr) {
                return addr;
            } catch {
                return address(0);
            }
        }
    }

    /**
     * @notice Check if string is number
     * @param s String to check
     * @return True if valid number
     */
    function isNumber(string memory s) internal pure returns (bool) {
        return LibString.is7BitASCII(s, ASCII_NUMBER_MASK);
    }

    /**
     * @notice Check if hex with 0x prefix
     * @param s String to check
     * @return True if valid hex
     */
    function isHexPrefixed(string memory s) internal pure returns (bool) {
        return bytes(s).length % 2 == 0 && LibString.startsWith(s, "0x")
            && LibString.is7BitASCII(s, ASCII_HEX_MASK_PREFIXED);
    }

    /**
     * @notice Check if hex without prefix
     * @param s String to check
     * @return True if valid hex
     */
    function isHexNoPrefix(string memory s) internal pure returns (bool) {
        return bytes(s).length % 2 == 0 && LibString.is7BitASCII(s, ASCII_HEX_MASK_NO_PREFIX);
    }

    /**
     * @notice Format number with decimals
     * @param value Number to format
     * @param decimals Decimal places in input
     * @param precision Output decimal places
     * @return result Formatted string
     */
    function formatDecimal(uint256 value, uint256 decimals, uint256 precision)
        internal
        pure
        returns (string memory result)
    {
        if (value == 0) return "0";
        if (decimals > 42) revert InvalidDecimals(); // Prevent overflow in 10**decimals
        if (precision > decimals) return value.toString();

        /// @solidity memory-safe-assembly
        assembly {
            let whole := div(value, exp(10, decimals))
            let decimalValue := div(mod(value, exp(10, decimals)), exp(10, sub(decimals, precision)))

            // We allocate max needed memory: 78 digits + 1 decimal point
            result := add(mload(0x40), 0x80)
            mstore(0x40, add(result, 0x20))

            let end := result
            let w := not(0) // -1 for subtraction

            // Write decimal digits from right to left if we have them
            if gt(decimalValue, 0) {
                let check := 0
                for { let i := 0 } lt(i, precision) { i := add(i, 1) } {
                    let digit := mod(decimalValue, 10)
                    if or(gt(digit, 0), gt(check, 0)) {
                        result := add(result, w)
                        mstore8(result, add(48, digit))
                        if iszero(check) { check := 1 }
                    }
                    decimalValue := div(decimalValue, 10)
                }
                result := add(result, w)
                mstore8(result, 0x2e) // "."
            }

            // Write whole number from right to left
            switch whole
            case 0 {
                result := add(result, w)
                mstore8(result, 48) // "0"
            }
            default {
                let temp := whole
                for {} gt(temp, 0) { temp := div(temp, 10) } {
                    result := add(result, w)
                    mstore8(result, add(48, mod(temp, 10)))
                }
            }

            let length := sub(end, result)
            result := sub(result, 0x20)
            mstore(result, length)
        }
    }

    /**
     * @notice Calculate value in USDC (6 decimals)
     * @param _balance Token balance
     * @param price USDC price
     * @param decimals Token decimals
     * @return value Result in USDC
     */
    function calculateUSDCValue(uint256 _balance, uint256 price, uint8 decimals)
        internal
        pure
        returns (uint256 value)
    {
        if (decimals > 42) revert InvalidDecimals(); // Prevent overflow in 10**decimals

        /// @solidity memory-safe-assembly
        assembly {
            // Handle zero cases first
            //if or(iszero(_balance), iszero(price)) { value := 0 } // it's auto 0 if 0
            if not(or(iszero(_balance), iszero(price))) {
                switch gt(decimals, 6)
                case 1 {
                    // If decimals > 6 (like ETH's 18 decimals)
                    value := div(mul(_balance, price), exp(10, decimals)) // Result is in USDC's 6 decimals
                }
                default {
                    switch lt(decimals, 6)
                    case 1 {
                        // If decimals < 6
                        value := mul(div(mul(_balance, price), 1000000), exp(10, sub(6, decimals))) // Then scale up to 6 decimals
                    }
                    default {
                        // If decimals == 6
                        value := div(mul(_balance, price), 1000000)
                    }
                }
            }
        }
    }
}
