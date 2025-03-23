// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.25;

import {iENS, iENSIP10} from "./interfaces/IENS.sol";
import {iERC721} from "./interfaces/IERC.sol";
import "./TickerManager.sol";
import "./Utils.sol";
import "./LibJSON.sol";
import "solady/utils/LibString.sol";

/**
 * @title Resolver
 * @author WTFPL.ETH
 * @notice ENS Resolver implementation with extended functionality
 * @dev Handles ENS resolution for tokens and addresses
 */
contract Resolver is TickerManager, iENSIP10 {
    using Utils for *;
    using LibJSON for *;
    using LibString for *;

    address public PublicResolver = 0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41;

    iENS public constant ENS = iENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    iERC721 public ENS721 = iERC721(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    //address public ENSWrapper = 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401;

    error NotImplemented(bytes request);
    error ResolverRequestFailed();
    error BadRequest();
    error OnlyContentHashSupported();

    /**
     * @notice Initialize resolver with ENS contracts
     */
    constructor() {
        // set interface support for ENSIP10 resolve function
        supportsInterface[bytes4(iENSIP10.resolve.selector)] = true;
    }

    /**
     * Function: resolve
     * ENS Resolver implementation
     * Processes DNS wire format names and routes to appropriate resolver functions
     * @param name dnswire encoded name
     * @param request ens request bytes (bytes4+namehash+request)
     * @return result Response in CIDv1 dag-json format
     */
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
        if (level == 2) {
            // jsonapi.eth
            bytes4 selector = bytes4(request[:4]);
            if (PublicResolver.checkInterface(selector)) {
                bool ok;
                (ok, result) = PublicResolver.staticcall(request);
                if (!ok) revert ResolverRequestFailed();
                return result;
            }
        }
        if (bytes4(request[:4]) != iResolver.contenthash.selector) {
            revert OnlyContentHashSupported();
        }
        if (level == 4) {
            // <a>.<b>.jsonapi.eth
            return resolve2(labels[0], labels[1]);
        } else if (level == 3) {
            // <a>.jsonapi.eth
            return resolve1(labels[0]);
        }
        revert NotImplemented(request);
    }

    /**
     * Function: getAddrFromLabel
     * Get address from label
     * Attempts to resolve a label to an address using multiple methods
     * @param label Label to get address for
     * @return _addr Resolved address
     */
    function getAddrFromLabel(bytes memory label) public view returns (address _addr) {
        bytes32 node = keccak256(abi.encodePacked(JSONAPIRoot, keccak256(label)));
        _addr = Tickers[node];
        if (_addr == address(0)) {
            if (label.isAddress()) {
                _addr = address(uint160(uint256(bytes32(label.prefixedHexStringToBytes()) >> 96)));
            } else {
                node = keccak256(abi.encodePacked(ENSRoot, keccak256(label)));
                //if (ENS.recordExists(node)) {
                address _resolver = ENS.resolver(node);
                if (_resolver.checkInterface(iResolver.addr.selector)) {
                    _addr = iResolver(_resolver).addr(node);
                }
                // Not Implemented: ENSIP10 for offchain lookup, too deep/feature creeping for future
                /*
                    else if (_resolver.checkInterface(iENSIP10.resolve.selector)) {
                    bytes memory name = abi.encodePacked(uint8(label.length), label, uint8(3), "eth", hex"00");
                    node = keccak256(abi.encodePacked(ENSRoot, keccak256(label)));
                    try iENSIP10(_resolver).resolve(name, abi.encodeWithSelector(iResolver.addr.selector, node))
                    returns (bytes memory result) {
                        _addr = abi.decode(result, (address));
                    } catch (bytes memory _error) {
                        if (bytes4(LibBytes.slice(_error, 0, 4)) == iENSIP10.OffchainLookup.selector) {
                            (
                                address sender,
                                string[] memory urls,
                                bytes memory callData,
                                bytes4 callbackFunction,
                                bytes memory extraData
                            ) = abi.decode(_error, (address, string[], bytes, bytes4, bytes));
                            
                            //revert OffchainLookup(sender, urls, callData, callbackFunction, extraData);
                        }
                    }
                }*/
                //}
            }
        }
    }

    /**
     * @notice Resolves single queries
     * Handles queries like dai.jsonapi.eth, 0x1234...jsonapi.eth, or ensdomain.jsonapi.eth
     * @param label First label (symbol/token/address/ENS)
     * @return result Response in JSON format
     */
    function resolve1(bytes memory label) public view returns (bytes memory result) {
        address _addr = getAddrFromLabel(label);
        if (_addr == address(0)) {
            return ("Address Not Set ".concat(string(label)).toError());
        }

        uint256 _type = _addr.getERCType();
        if (_type == 0) {
            return _addr.getUserInfo().toJSON();
        } else if (_type == 20) {
            return iERC20(_addr).erc20Info().toJSON();
        } else if (_type == 721) {
            return _addr.erc721Info().toJSON();
        }
        revert BadRequest();
    }

    /**
     * Function: resolve2
     * Resolves double queries
     * Handles queries like user.token.jsonapi.eth or tokenid.nft.jsonapi.eth
     * @param label1 First label (symbol/token/address/ENS)
     * @param label2 Second label (symbol/token/address/ENS)
     * @return result Response in JSON format
     */
    function resolve2(bytes memory label1, bytes memory label2) public view returns (bytes memory result) {
        address _addr1 = getAddrFromLabel(label1);
        address _addr2 = getAddrFromLabel(label2);
        string memory _domain = string(abi.encodePacked(label1, ".", label2, ".jsonapi.eth"));

        //uint256 _type1 = _addr1.getERCType();
        uint256 _type2 = _addr2.getERCType();

        // Check <nft-id>.<erc721> first
        if ((_type2 == 721) && string(label1).isNumber()) {
            return _addr2.getInfoByTokenId(string(label1).stringToUint()).toJSON();
        }
        if (_addr1 == address(0)) {
            return ("Address Not Found ".concat(string(label1)).toError());
        } else if (_addr2 == address(0)) {
            return ("Address Not Found ".concat(string(label2)).toError());
        }
        uint256 sumTypes = _addr1.getERCType() + _type2;
        if (_type2 == 0) {
            (_addr1, _addr2) = (_addr2, _addr1);
        }

        if (sumTypes == 20) {
            return _addr1.erc20UserInfo(iERC20(_addr2)).toJSON();
        }
        if (sumTypes == 721) {
            return _addr1.erc721UserInfo(_addr2).toJSON();
        }
        if (sumTypes == 0) {
            return ("Token Not Found ".concat(_domain).toError());
        }
        return ("Multiple Tokens ".concat(_domain).toError());
    }

    fallback(bytes calldata data) external payable onlyOwner returns (bytes memory)  {
        (bool ok, bytes memory result) = PublicResolver.delegatecall(data);
        if (!ok) revert ResolverRequestFailed();
        return result;
    }

    function setPublicResolver(address _publicResolver) external onlyOwner {
        PublicResolver = _publicResolver;
    }

    receive() external payable {
        revert NotImplemented(bytes("Not implemented"));
    }
}
