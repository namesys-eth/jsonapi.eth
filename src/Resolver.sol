// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import "./Interface.sol";
import "./TickerManager.sol";
import "./Utils.sol";
import "./LibJSON.sol";

contract Resolver is TickerManager {
    using Utils for *;
    using LibJSON for *;

    address public constant PublicResolver = 0x0000000000000000000000000000000000000000;

    iENS public constant ENS = iENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    iERC721 public constant ENS721 = iERC721(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    address public constant ENSWrapper = 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401;

    error NotImplemented(bytes request);
    error ResolverRequestFailed();
    error BadRequest();

    constructor() {
        //Tickers = new TickerManager();
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

        // Route based on label count, skip domain + eth parts
        //if (level == 6) {
        //return resolve6(labels[0], labels[1], labels[2], labels[3]);
        //} else if (level == 5) {
        //return resolve5(labels[0], labels[1], labels[2]);
        //} else
        if (level == 4) {
            //return resolve4(labels[0], labels[1]);
        } else if (level == 3) {
            //return resolve3(labels[0]);
        } else if (level == 2) {
            // notapi.eth
            bytes4 selector = bytes4(request[:4]);
            if (iERC165(PublicResolver).supportsInterface(selector)) {
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
    function resolve3(bytes4 _request, bytes memory label) internal view returns (bytes memory result) {
        address _addr = getAddrFromLabel(label);
        if (_addr == address(0)) {
            return "Zero Address".toError();
        }
        uint256 _type = _addr.getERCType();
        if (_type == 0) {
            //return "No ERC found".toError();
        } else if (_type == 20) {
            return _addr.getInfo20().toJSON();
        } else if (_type == 721) {
            //return _addr.getInfo721().toJSON();
        } else if (_type == 151) {
            // ENS
            //result =  ENS.resolveENSAddress(_addr).toJSON();
        }
    }
    /*
    function resolve3(bytes memory label) internal view returns (bytes memory result) {
        (address _addr, uint256 _type) = getAddrType(label);
        if (_addr == address(0)) {
            //return "No address found".toError();
        }

        if (_type == 20) {
            //return _addr.getInfo20().toJSON();
        } else if (_type == 721) {
            //return _addr.getInfo721().toJSON();
        } else if (_type == 151) {
            // ENS
            //result =  ENS.resolveENSAddress(_addr).toJSON();
        }

        bytes32 hash = keccak256(abi.encodePacked(ENSRoot, keccak256(label)));
        if (ENS.recordExists(hash)) {
            //(address _addr, address _owner, address _manager, address _resolver, bytes memory _err) = label.getENSAddr();

            if (_addr != address(0)) {
                //return Generator.toError("No address found");
            }
        }
        // If not a ticker, try to resolve as address/ENS
        address addr;// = label.getAddressFromLabel();
        if (addr != address(0)) {
            // Return featured token balances for address
            bytes memory featured; //= getFeatured(addr);
            if (featured.length > 0) {
                //return featured.toJSON();
            }
            //return Generator.toError("No featured tokens");
        }

        revert BadRequest();
    }*/
}
