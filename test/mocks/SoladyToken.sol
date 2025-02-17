// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

import {ERC20} from "solady/tokens/ERC20.sol";
import "../../src/Interface.sol";

contract SoladyToken is ERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor() {
        _name = "Test Token";
        _symbol = "TEST";
        _decimals = 18;
        _mint(msg.sender, 1000000e18); // 1M tokens
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
