// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Resolver} from "../src/Resolver.sol";

contract ResolverScript is Script {
    Resolver public resolver;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        // resolver = new Resolver();
        vm.stopBroadcast();
    }
}
