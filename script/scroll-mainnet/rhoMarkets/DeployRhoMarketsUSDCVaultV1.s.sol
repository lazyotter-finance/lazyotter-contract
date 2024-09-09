// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Script.sol";
import {ScrollMainnet} from "../../../config/AddressBook.sol";

import {IRErc20Delegator} from "../../../src/interfaces/rhoMarkets/IRErc20Delegator.sol";

import {RhoMarketsVault} from "../../../src/vaultsUpgradable/v1/RhoMarketsVault.sol";
import {Beacon} from "../../../src/vaultsUpgradable/Beacon.sol";
import {Proxy} from "../../../src/vaultsUpgradable/Proxy.sol";

contract Deploy is Script {
    // TODO: set treasury, keeper addresses
    address treasury = ScrollMainnet.LO_TREASURY;
    address keeper = ScrollMainnet.KEEPER;

    IERC20 USDC = IERC20(ScrollMainnet.USDC);

    IRErc20Delegator public RUSDC = IRErc20Delegator(ScrollMainnet.RHO_MARKETS_USDC);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the implementation contract
        RhoMarketsVault vaultImplementation = new RhoMarketsVault();

        // Deploy the UpgradeableBeacon
        Beacon beacon = new Beacon(address(vaultImplementation));

        // Prepare initialization data for the vault
        bytes memory initData = abi.encodeCall(RhoMarketsVault.initialize, (USDC, "LazyOtter: Vault RhoMarkets USDC", "LOT", keeper, RUSDC));

        // Deploy the BeaconProxy
        Proxy proxy = new Proxy(address(beacon), initData);

        vm.stopBroadcast();

        console2.log("SCROLL_RHOMARKETS_BEACON=%s", address(beacon));
        console2.log("SCROLL_RHOMARKETS_USDC_VAULT_PROXY=%s", address(proxy));
        console2.log("SCROLL_RHOMARKETS_USDC_VAULT_IMPLEMENTATION=%s", address(vaultImplementation));
    }
}
