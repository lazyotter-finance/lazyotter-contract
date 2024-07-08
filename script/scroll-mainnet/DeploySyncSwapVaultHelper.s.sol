// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {ScrollMainnet} from "../../config/AddressBook.sol";

import {IRouter} from "../../src/interfaces/syncswap/IRouter.sol";
import {SyncSwapVaultHelper} from "../../src/helper/SyncSwapVaultHelper.sol";

contract Deploy is Script {
    IRouter router = IRouter(ScrollMainnet.SYNCSWAP_ROUTER);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        SyncSwapVaultHelper syncSwapVaultHelper = new SyncSwapVaultHelper(router);

        vm.stopBroadcast();

        console2.log("SCROLL_MAINNET_SYNCSWAP_VAULT_HELPER=%s", address(syncSwapVaultHelper));
    }
}
