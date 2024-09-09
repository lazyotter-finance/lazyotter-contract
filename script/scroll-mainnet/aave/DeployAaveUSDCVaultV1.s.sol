// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Script.sol";
import {ScrollMainnet} from "../../../config/AddressBook.sol";

import {IDataProvider} from "../../../src/interfaces/aave/IDataProvider.sol";
import {ILendingPool} from "../../../src/interfaces/aave/ILendingPool.sol";

import {AaveVault} from "../../../src/vaultsUpgradable/v1/AaveVault.sol";
import {Beacon} from "../../../src/vaultsUpgradable/Beacon.sol";
import {Proxy} from "../../../src/vaultsUpgradable/Proxy.sol";

contract Deploy is Script {
    // TODO: set treasury, keeper addresses
    address treasury = ScrollMainnet.LO_TREASURY;
    address keeper = ScrollMainnet.KEEPER;

    IERC20 USDC = IERC20(ScrollMainnet.USDC);

    IDataProvider dataProvider = IDataProvider(ScrollMainnet.AAVE_DATAPROVIDER);
    ILendingPool lendingPool = ILendingPool(ScrollMainnet.AAVE_LENDINGPOOL);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the implementation contract
        AaveVault vaultImplementation = new AaveVault();

        // Deploy the UpgradeableBeacon
        Beacon beacon = new Beacon(address(vaultImplementation));

        // Prepare initialization data for the vault
        bytes memory initData = abi.encodeCall(
            AaveVault.initialize,
            (USDC, "LazyOtter: Vault Aave USDC", "LOT", keeper, dataProvider, lendingPool)
        );

        // Deploy the BeaconProxy
        Proxy proxy = new Proxy(address(beacon), initData);

        vm.stopBroadcast();

        console2.log("SCROLL_AAVE_BEACON=%s", address(beacon));
        console2.log("SCROLL_AAVE_USDC_VAULT_PROXY=%s", address(proxy));
        console2.log("SCROLL_AAVE_USDC_VAULT_IMPLEMENTATION=%s", address(vaultImplementation));
    }
}
