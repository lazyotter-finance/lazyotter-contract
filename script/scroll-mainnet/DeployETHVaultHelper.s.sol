// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {ScrollMainnet} from "../../config/AddressBook.sol";

import {ETHVaultHelper} from "../../src/helper/ETHVaultHelper.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        ETHVaultHelper ethVaultHelper = new ETHVaultHelper(ScrollMainnet.WETH);

        vm.stopBroadcast();

        console2.log("SCROLL_MAINNET_ETH_VAULT_HELPER=%s", address(ethVaultHelper));
    }
}
