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

    IERC20 WETH = IERC20(ScrollMainnet.WETH);

    IDataProvider dataProvider = IDataProvider(ScrollMainnet.AAVE_DATAPROVIDER);
    ILendingPool lendingPool = ILendingPool(ScrollMainnet.AAVE_LENDINGPOOL);
    address beacon = ScrollMainnet.AAVE_BEACON;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Prepare initialization data for the vault
        bytes memory initData = abi.encodeCall(
            AaveVault.initialize, (WETH, "LazyOtter: Vault Aave WETH", "LOT", keeper, dataProvider, lendingPool)
        );

        // Deploy the BeaconProxy
        Proxy proxy = new Proxy(address(beacon), initData);

        vm.stopBroadcast();

        console2.log("SCROLL_AAVE_BEACON=%s", address(beacon));
        console2.log("SCROLL_AAVE_WETH_VAULT_PROXY=%s", address(proxy));
    }
}
