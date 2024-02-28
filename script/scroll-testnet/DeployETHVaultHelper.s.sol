// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {ScrollTestnet} from "../../config/AddressBook.sol";

import {ETHVaultHelper} from "../../src/helper/ETHVaultHelper.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        ETHVaultHelper ethVaultHelper = new ETHVaultHelper(ScrollTestnet.WETH);

        vm.stopBroadcast();

        console2.log("SCROLL_TESTNET_ETH_VAULT_HELPER=%s", address(ethVaultHelper));
    }
}
