// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Script.sol";
import {ScrollMainnet} from "../../../config/AddressBook.sol";

import {ICrocSwapDex} from "../../../src/interfaces/ambient/ICrocSwapDex.sol";

import {AmbientVaultHelper} from "../../../src/helper/AmbientVaultHelper.sol";
import {AmbientVault} from "../../../src/vaultsUpgradable/v1/AmbientVault.sol";
import {CrocLpErc20} from "../../../src/utils/CrocLpErc20.sol";
import {Beacon} from "../../../src/vaultsUpgradable/Beacon.sol";
import {Proxy} from "../../../src/vaultsUpgradable/Proxy.sol";

contract Deploy is Script {
    // TODO: set treasury, keeper addresses
    address treasury = ScrollMainnet.LO_TREASURY;
    address keeper = ScrollMainnet.KEEPER;

    ICrocSwapDex crocSwapDex = ICrocSwapDex(ScrollMainnet.AMBIENT_SWAPDEX);
    IERC20 WBTC = IERC20(ScrollMainnet.WBTC);
    IERC20 ETH = IERC20(address(0));
    IERC20 wrsETH = IERC20(ScrollMainnet.wrsETH);
    IERC20 wstETH = IERC20(ScrollMainnet.wstETH);
    address beacon = ScrollMainnet.AMBIENT_BEACON;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        CrocLpErc20 crocLpErc20 = new CrocLpErc20(crocSwapDex, address(ETH), address(WBTC), 420);

        // Prepare initialization data for the vault
        bytes memory initData = abi.encodeCall(
            AmbientVault.initialize,
            (IERC20(address(crocLpErc20)), "LazyOtter: Vault Ambient ETH WBTC", "LOT", keeper, 100_000)
        );

        // Deploy the BeaconProxy
        Proxy proxy = new Proxy(address(beacon), initData);

        vm.stopBroadcast();

        console2.log("SCROLL_AMBIENT_BEACON=%s", address(beacon));
        console2.log("SCROLL_AMBIENT_WBTC_ETH_VAULT_PROXY=%s", address(proxy));
    }
}
