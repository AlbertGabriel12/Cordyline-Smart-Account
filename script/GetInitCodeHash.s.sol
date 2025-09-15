// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

import {CordylineAccountFactory} from "../src/CordylineAccountFactory.sol";
import {MultiOwnerCordylineAccountFactory} from "../src/MultiOwnerCordylineAccountFactory.sol";

contract GetInitCodeHash is Script {
    // Load entrypoint from env
    address public entryPointAddr = vm.envAddress("ENTRYPOINT");
    IEntryPoint public entryPoint = IEntryPoint(payable(entryPointAddr));

    // Load factory owner from env
    address public owner = vm.envAddress("OWNER");

    function run() public view {
        console.log("******** Calculating Init Code Hashes *********");
        console.log("Chain: ", block.chainid);
        console.log("EP: ", entryPointAddr);
        console.log("Factory owner: ", owner);

        bytes memory CordylineAccountFactoryInitCode =
            abi.encodePacked(type(CordylineAccountFactory).creationCode, abi.encode(owner, entryPoint));

        bytes32 CordylineAccountFactoryInitCodeHash = keccak256(CordylineAccountFactoryInitCode);

        console.log("CordylineAccountFactory init code hash:");
        console.logBytes32(CordylineAccountFactoryInitCodeHash);

        bytes memory multiOwnerCordylineAccountFactoryInitCode =
            abi.encodePacked(type(MultiOwnerCordylineAccountFactory).creationCode, abi.encode(owner, entryPoint));

        bytes32 multiOwnerCordylineAccountFactoryInitCodeHash = keccak256(multiOwnerCordylineAccountFactoryInitCode);

        console.log("MultiOwnerCordylineAccountFactory init code hash:");
        console.logBytes32(multiOwnerCordylineAccountFactoryInitCodeHash);
    }
}
