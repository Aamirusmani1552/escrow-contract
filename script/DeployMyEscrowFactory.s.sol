// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {MyEscrowFactory} from "../src/MyEscrowFactory.sol";
import {MyEscrow} from "../src/MyEscrow.sol";

contract DeployMyEscrowFactory is Script {
    function run() external returns (MyEscrowFactory) {
        vm.startBroadcast();
        MyEscrowFactory factory = new MyEscrowFactory();
        vm.stopBroadcast();
        return factory;
    }
}
