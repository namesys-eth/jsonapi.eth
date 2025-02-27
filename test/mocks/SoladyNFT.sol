// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import {ERC721} from "solady/tokens/ERC721.sol";
import {iERC721, iERC721ContractMetadata} from "../../src/interfaces/IERC.sol";

contract SoladyNFT is ERC721, iERC721ContractMetadata {
    string private _name;
    string private _symbol;

    constructor() {
        _name = "Test NFT";
        _symbol = "TNFT";
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "test";
    }

    function contractURI() public pure override returns (string memory) {
        return "test";
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(iERC721).interfaceId || interfaceId == type(iERC721ContractMetadata).interfaceId;
    }

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}
