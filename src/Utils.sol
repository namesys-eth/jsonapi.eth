// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

/**
 * Title: Utils
 * Author: WTFPL.ETH
 * Description: Utility functions for token and address operations
 *
 * This library provides utility functions for various operations related to tokens,
 * addresses, and data formatting. It includes helpers for ENS resolution, token type detection,
 * string manipulation, and numeric conversions.
 *
 * Key features:
 * - Token type detection (ERC20, ERC721)
 * - ENS name resolution
 * - String and address formatting
 * - Numeric conversions with decimal handling
 */
import {iERC20, iERC721, iERC721Metadata, iERC165} from "./interfaces/IERC.sol";
import {iENS, iENSReverse, iResolver} from "./interfaces/IENS.sol";
import {iCheckTheChainEthereum} from "./interfaces/ICheckTheChain.sol";
import {LibString} from "solady/utils/LibString.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";
import {LibJSON} from "./LibJSON.sol";

library Utils {
    using LibString for *;

    iCheckTheChainEthereum internal constant CTC = iCheckTheChainEthereum(0x0000000000cDC1F8d393415455E382c30FBc0a84);
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
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
    error NotERC721Metadata();
    error InvalidInput();

    /**
     * @notice Convert ASCII Hex string to bytes
     * @param input Hex string with "0x" prefix
     * @return result Converted bytes
     */
    function prefixedHexStringToBytes(bytes memory input) internal pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(result, shr(1, sub(mload(input), 2)))
            mstore(0x40, add(result, add(0x20, mload(result))))
            let len := mload(input)
            let inPtr := add(input, 0x20)
            for { let i := 2 } lt(i, len) { i := add(i, 2) } {
                let b1 := sub(byte(0, mload(add(inPtr, i))), 48)
                let b2 := sub(byte(0, mload(add(inPtr, add(i, 1)))), 48)
                b1 := sub(b1, mul(39, gt(b1, 9)))
                b2 := sub(b2, mul(39, gt(b2, 9)))
                mstore8(add(add(result, 0x20), div(sub(i, 2), 2)), add(shl(4, b1), b2))
            }
        }
    }

    /**
     * @notice Convert string to uint256
     * @param s String containing only digits
     * @return result Parsed number
     */
    function stringToUint(string memory s) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let end := add(mload(s), add(s, 0x20))
            for { let ptr := add(s, 0x20) } lt(ptr, end) { ptr := add(ptr, 1) } {
                result := add(mul(result, 10), sub(byte(0, mload(ptr)), 48))
            }
        }
    }

    /**
     * @notice Check if input is valid ETH address string
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
     * @return Owner address as hex string
     */
    function getNFTOwner(address _contract, uint256 _tokenId) internal view returns (string memory) {
        try iERC721(_contract).ownerOf(_tokenId) returns (address owner) {
            return owner.toHexString();
        } catch {
            return "0x0000000000000000000000000000000000000000";
        }
    }

    /**
     * @notice Get NFT token URI
     * @param _contract NFT address
     * @param _tokenId Token ID
     * @return _tokenURI The token URI string
     */
    function getTokenURI(address _contract, uint256 _tokenId) internal view returns (string memory _tokenURI) {
        try iERC721Metadata(_contract).tokenURI(_tokenId) returns (string memory tokenURI) {
            if (tokenURI.contains('"')) {
                return tokenURI.escapeJSON();
            }
            return tokenURI;
        } catch {}
    }

    iENSReverse internal constant ENSReverse = iENSReverse(0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb);

    /**
     * @notice Get ENS reverse record
     * @param _addr Address to lookup
     * @return _name Primary ENS name
     */
    function getPrimaryName(address _addr) internal view returns (string memory _name) {
        bytes32 node = ENSReverse.node(_addr);
        address resolver = ENS.resolver(node);
        if (resolver.code.length > 0) {
            try iResolver(resolver).name(node) returns (string memory name_) {
                node = getNamehash(name_);
                resolver = ENS.resolver(node);
                if (resolver.code.length > 0) {
                    try iResolver(resolver).addr(node) returns (address payable addr_) {
                        if (_addr == addr_) return name_;
                    } catch {}
                }
            } catch {}
        }
    }

    function getNamehash(string memory domain) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := add(domain, 32)
            let end := add(ptr, mload(domain))
            let tempStart := end
            let tempEnd := end

            for {} lt(ptr, end) {} {
                end := sub(end, 1)
                if eq(byte(0, mload(end)), 0x2e) {
                    mstore(0x00, result)
                    mstore(0x20, keccak256(tempStart, sub(tempEnd, tempStart)))
                    result := keccak256(0x00, 0x40)
                    tempEnd := end
                    tempStart := tempEnd
                    continue
                }
                tempStart := end
            }

            mstore(0x00, result)
            mstore(0x20, keccak256(tempStart, sub(tempEnd, tempStart)))
            result := keccak256(0x00, 0x40)
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
        return isERC20(addr) ? 20 : isERC721(addr) ? 721 : 0;
    }

    /**
     * @notice Get token price in USDC
     * @param _token Token address
     * @return Price and formatted string
     */
    function checkTheChain(address _token) internal view returns (uint256, string memory) {
        if (_token == USDC) {
            return (1e6, "1"); // hardcode USDC price to 1
        }
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
        if (checkInterface(_resolver, iResolver.addr.selector)) {
            try iResolver(_resolver).addr(node) returns (address payable addr) {
                return addr;
            } catch {}
        }
    }

    /**
     * @notice Check if string is number
     * @param s String to check
     * @return True if valid number
     */
    function isNumber(string memory s) internal pure returns (bool) {
        return s.is7BitASCII(ASCII_NUMBER_MASK);
    }

    /**
     * @notice Check if hex with 0x prefix
     * @param s String to check
     * @return True if valid hex
     */
    function isHexPrefixed(string memory s) internal pure returns (bool) {
        return s.startsWith("0x") && bytes(s).length % 2 == 0 && s.is7BitASCII(ASCII_HEX_MASK_PREFIXED);
    }

    /**
     * @notice Format number with decimals
     * @param value Number to format
     * @param decimals Decimal places in input
     * @return result Formatted string
     */
    function toDecimal(uint256 value, uint256 decimals) internal pure returns (string memory result) {
        assembly ("memory-safe") {
            if eq(value, 0) {
                result := add(mload(0x40), 0x20)
                mstore(result, 0x30)
                return(result, 1)
            }

            let whole := div(value, exp(10, decimals))
            let precision := 6
            //if iszero(whole) { precision := 6 }
            if gt(precision, decimals) { precision := decimals }

            let decimalValue := div(mod(value, exp(10, decimals)), exp(10, sub(decimals, precision)))

            // We allocate max needed memory: 78 digits + 1 decimal point
            result := add(mload(0x40), 0x80)
            mstore(0x40, add(result, 0x20))

            let end := result
            let w := not(0) // -1 for subtraction

            // Write decimal digits from right to left if we have them
            if gt(decimalValue, 0) {
                let check := 0 // skip trailing zeros from decimal value
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
    function toUSDC(uint256 _balance, uint256 price, uint8 decimals) internal pure returns (uint256 value) {
        assembly ("memory-safe") {
            if not(or(iszero(_balance), iszero(price))) {
                switch gt(decimals, 6)
                case 1 { value := div(mul(_balance, price), exp(10, decimals)) }
                default {
                    switch lt(decimals, 6)
                    case 1 { value := mul(div(mul(_balance, price), 1000000), exp(10, sub(6, decimals))) }
                    default { value := div(mul(_balance, price), 1000000) }
                }
            }
        }
    }
}
