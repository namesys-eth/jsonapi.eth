// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Resolver} from "../src/Resolver.sol";

contract ResolverScript is Script {
    Resolver public resolver;

    function setUp() public {}

    function run() public {
        address publicResolver = 0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41;
        address ens721 = 0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85;
        address ensWrapper = 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401
        ;
        if (block.chainid == 11155111) {
            publicResolver = 0x8948458626811dd0c23EB25Cc74291247077cC51;
            ensWrapper = 0x0635513f179D50A207757E05759CbD106d7dFcE8;
        }
        vm.startBroadcast();
        resolver = new Resolver(publicResolver, ens721, ensWrapper);
        vm.stopBroadcast();
    }
}
