// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {DecentralizedBank} from "../src/DecentralizedBank.sol";

contract DecentralizedBankScript is Script {
    function run() external returns (DecentralizedBank decentralizedBank) {
        vm.startBroadcast();

        decentralizedBank = new DecentralizedBank();

        vm.stopBroadcast();
    }
}
