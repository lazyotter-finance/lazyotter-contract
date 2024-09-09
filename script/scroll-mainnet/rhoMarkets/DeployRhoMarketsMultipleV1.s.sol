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
    address beacon = ScrollMainnet.RHO_MARKETS_BEACON;

    IERC20 USDT = IERC20(ScrollMainnet.USDT);
    IERC20 WETH = IERC20(ScrollMainnet.WETH);
    IERC20 wstETH = IERC20(ScrollMainnet.wstETH);
    IERC20 weETH = IERC20(ScrollMainnet.weETH);
    IERC20 wrsETH = IERC20(ScrollMainnet.wrsETH);
    IERC20 STONE = IERC20(ScrollMainnet.STONE);

    IRErc20Delegator public RUSDT = IRErc20Delegator(ScrollMainnet.RHO_MARKETS_RUSDT);
    IRErc20Delegator public RwstETH = IRErc20Delegator(ScrollMainnet.RHO_MARKETS_RwstETH);
    IRErc20Delegator public RweETH = IRErc20Delegator(ScrollMainnet.RHO_MARKETS_RweETH);
    IRErc20Delegator public RwrsETH = IRErc20Delegator(ScrollMainnet.RHO_MARKETS_RwrsETH);
    IRErc20Delegator public RSTONE = IRErc20Delegator(ScrollMainnet.RHO_MARKETS_RSTONE);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // deploy RUSDT vault
        bytes memory initData = abi.encodeCall(
            RhoMarketsVault.initialize,
            (USDT, "LazyOtter: Vault RhoMarkets USDT", "LOT", keeper, RUSDT)
        );
        Proxy proxy = new Proxy(address(beacon), initData);
        console2.log("SCROLL_RHOMARKETS_USDT_VAULT_PROXY=%s", address(proxy));

        // deploy RwstETH vault
        initData = abi.encodeCall(
            RhoMarketsVault.initialize,
            (wstETH, "LazyOtter: Vault RhoMarkets wstETH", "LOT", keeper, RwstETH)
        );
        proxy = new Proxy(address(beacon), initData);
        console2.log("SCROLL_RHOMARKETS_WSTETH_VAULT_PROXY=%s", address(proxy));

        // deploy RweETH vault
        initData = abi.encodeCall(
            RhoMarketsVault.initialize,
            (weETH, "LazyOtter: Vault RhoMarkets weETH", "LOT", keeper, RweETH)
        );
        proxy = new Proxy(address(beacon), initData);
        console2.log("SCROLL_RHOMARKETS_WEETH_VAULT_PROXY=%s", address(proxy));

        // deploy RwrsETH vault
        initData = abi.encodeCall(
            RhoMarketsVault.initialize,
            (wrsETH, "LazyOtter: Vault RhoMarkets wrsETH", "LOT", keeper, RwrsETH)
        );
        proxy = new Proxy(address(beacon), initData);
        console2.log("SCROLL_RHOMARKETS_WRSETH_VAULT_PROXY=%s", address(proxy));

        // deploy RSTONE vault
        initData = abi.encodeCall(
            RhoMarketsVault.initialize,
            (STONE, "LazyOtter: Vault RhoMarkets STONE", "LOT", keeper, RSTONE)
        );
        proxy = new Proxy(address(beacon), initData);
        console2.log("SCROLL_RHOMARKETS_STONE_VAULT_PROXY=%s", address(proxy));

        vm.stopBroadcast();

        console2.log("SCROLL_RHOMARKETS_BEACON=%s", address(beacon));
    }
}
