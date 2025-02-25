// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import {iENS, iENSIP10} from "./interfaces/IENS.sol";
import {iERC721} from "./interfaces/IERC.sol";
import "./TickerManager.sol";
import "./Utils.sol";
import "./LibJSON.sol";
import "solady/utils/LibString.sol";

contract Resolver is TickerManager {
    using Utils for *;
    using LibJSON for *;
    using LibString for *;

    address public PublicResolver = 0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41;

    iENS public ENS = iENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    iERC721 public ENS721; // = iERC721(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    address public ENSWrapper; // = 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401;

    error NotImplemented(bytes request);
    error ResolverRequestFailed();
    error BadRequest();
    error OnlyContentHashSupported();

    constructor(address _publicResolver, address _ens721, address _ensWrapper) {
        PublicResolver = _publicResolver;
        ENS721 = iERC721(_ens721);
        ENSWrapper = _ensWrapper;
    }

    function resolve(bytes calldata name, bytes calldata request) external view returns (bytes memory result) {
        uint256 index;
        uint256 level;
        bytes[] memory labels = new bytes[](8);
        uint256 length;

        // Parse DNS wire format
        unchecked {
            while (name[index] > 0x0) {
                length = uint8(name[index++]);
                labels[level++] = name[index:index += length];
            }
        }
        if (level > 2 && bytes4(request[:4]) != iResolver.contenthash.selector) {
            revert OnlyContentHashSupported();
        }
        // Route based on label count, skip jsonapi.eth part
        if (level == 4) {
            // <a>.<b>.jsonapi.eth
            return resolve2(labels[0], labels[1]);
        } else if (level == 3) {
            // <a>.jsonapi.eth
            return resolve1(labels[0]);
        } else if (level == 2) {
            // jsonapi.eth
            bytes4 selector = bytes4(request[:4]);
            if (PublicResolver.checkInterface(selector)) {
                bool ok;
                (ok, result) = PublicResolver.staticcall(request);
                if (!ok) revert ResolverRequestFailed();
                return result;
            }
        }
        revert NotImplemented(request);
    }

    function getAddrFromLabel(bytes memory label) internal view returns (address _addr) {
        bytes32 node = keccak256(abi.encodePacked(JSONAPIRoot, keccak256(label)));
        _addr = Tickers[node]._addr;
        if (_addr == address(0)) {
            if (label.isAddress()) {
                _addr = address(uint160(uint256(bytes32(label.prefixedHexStringToBytes()) >> 96)));
            } else {
                node = keccak256(abi.encodePacked(ENSRoot, keccak256(label)));
                if (ENS.recordExists(node)) {
                    _addr = ENS.resolver(node).getENSAddress(node);
                }
            }
        }
    }

    /**
     * @notice Resolves single queries (e.g., dai.notapi.eth Or 0x<address>.notapi.eth or ensdomain.notapi.eth)
     * @param label First label (symbol/token/address/ENS)
     * @return result Response in JSON format
     */
    function resolve1(bytes memory label) internal view returns (bytes memory result) {
        address _addr = getAddrFromLabel(label);
        if (_addr == address(0)) {
            return "Zero Address/".concat(string(label)).toError();
        }

        uint256 _type = _addr.getERCType();
        if (_type == 0) {
            return getFeaturedUser(_addr).toJSON();
        } else if (_type == 20) {
            return _addr.getInfo20().toJSON();
        } else if (_type == 721) {
            return _addr.getInfo721().toJSON();
        }

        revert BadRequest();
    }

    function resolve2(bytes memory label1, bytes memory label2) internal view returns (bytes memory result) {
        // First check L2 address and type
        address _addr2 = getAddrFromLabel(label2);
        if (_addr2 == address(0)) {
            return "Zero Address/".concat(string(label2)).toError();
        }
        uint256 _type2 = _addr2.getERCType();

        // If L2 is ERC721 token
        if (_type2 == 721) {
            // Check if L1 is a token ID number
            if (string(label1).isNumber()) {
                return _addr2.getInfoByTokenId(string(label1).stringToUint()).toJSON();
            }
        }

        // Get L1 address and check validity
        address _addr1 = getAddrFromLabel(label1);
        if (_addr1 == address(0)) {
            return "Zero Address/".concat(string(label1)).toError();
        }
        uint256 _type1 = _addr1.getERCType();

        // If L2 is normal address (EOA)
        if (_type2 == 0) {
            if (_type1 == 20) {
                return _addr1.getUserInfo20(_addr2).toJSON();
            } else if (_type1 == 721) {
                return _addr1.getUserInfo721(_addr2).toJSON();
            }
            return "Invalid Token Type/".concat(string(label1)).toError();
        }

        // If L2 is ERC20 token and L1 is normal address
        if (_type2 == 20 && _type1 == 0) {
            return _addr1.getUserInfo20(_addr2).toJSON();
        }

        // If L2 is ERC721 token and L1 is normal address
        if (_type2 == 721 && _type1 == 0) {
            return _addr1.getUserInfo721(_addr2).toJSON();
        }

        revert BadRequest();
    }
}
