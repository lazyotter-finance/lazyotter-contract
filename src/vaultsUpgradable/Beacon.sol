// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract Beacon is UpgradeableBeacon {
    constructor(address implementation) UpgradeableBeacon(implementation, msg.sender) {}
}
