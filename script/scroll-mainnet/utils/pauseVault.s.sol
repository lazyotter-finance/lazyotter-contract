// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {ScrollMainnet} from "../../../config/AddressBook.sol";
import {AaveVault} from "../../../src/vaultsUpgradable/v1/AaveVault.sol";

contract PauseVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address aaveETHVault = 0x844Ccc93888CAeBbAd91332FCa1045e6926a084d;
        address aaveUSDCVault = 0x7100409BaAEDa121aB92f663e3Ddb898F11Ff745;

        vm.startBroadcast(deployerPrivateKey);

        AaveVault ethVault = AaveVault(aaveETHVault);
        AaveVault usdcVault2 = AaveVault(aaveUSDCVault);

        ethVault.pause();
        usdcVault2.pause();

        vm.stopBroadcast();

        console2.log("Vault paused: %s", address(ethVault));
        console2.log("Vault paused: %s", address(usdcVault2));
    }
}
