// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.0;

contract NonToken {
    fallback() external payable {
        revert();
    }
}
