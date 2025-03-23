// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Resolver} from "../src/Resolver.sol";
import {iResolver} from "../src/interfaces/IENS.sol";

contract ResolverScript is Script {
    Resolver public resolver;

    function setUp() public {}

    function run() public {
        console.log("This", address(this));
        console.log("Deployer", msg.sender);
        vm.startBroadcast();
        resolver = new Resolver();
        vm.stopBroadcast();
        console.log("Resolver deployed at", address(resolver));
        console.log("Resolver owner", resolver.owner());

        bytes memory name = abi.encodePacked(
            uint8(42),
            bytes("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"),
            uint8(7),
            bytes("jsonapi"),
            uint8(3),
            bytes("eth"),
            bytes1(0)
        );
        bytes memory result = resolver.resolve(name, abi.encodeWithSelector(iResolver.contenthash.selector, bytes32(0)));
        console.logBytes(result);
    }
}
