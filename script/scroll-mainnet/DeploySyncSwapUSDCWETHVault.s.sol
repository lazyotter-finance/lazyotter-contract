// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Script.sol";
import {ScrollMainnet} from "../../config/AddressBook.sol";

import {SyncSwapVaultHelper} from "../../src/helper/SyncSwapVaultHelper.sol";
import {SyncSwapVault} from "../../src/vaults/SyncSwapVault.sol";
import {Vault} from "../../src/vaults/Vault.sol";

contract Deploy is Script {
    // TODO: set treasury, keeper addresses
    address treasury = ScrollMainnet.LO_TREASURY;
    address keeper = ScrollMainnet.KEEPER;

    IERC20 SYNCSWAP_USDC_WETH_LP = IERC20(ScrollMainnet.SYNCSWAP_USDC_WETH_LP);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address[] memory recipients = new address[](1);
        recipients[0] = treasury;

        uint256[] memory recipientWeights = new uint256[](1);
        recipientWeights[0] = 500;

        Vault.FeeInfo memory feeInfo = Vault.FeeInfo(recipients, recipientWeights, 200, 0, 0);

        vm.startBroadcast(deployerPrivateKey);

        SyncSwapVault syncSwapVault = new SyncSwapVault(
            SYNCSWAP_USDC_WETH_LP,
            "LazyOtter: Vault SYNCSWAP USDC WETH",
            "LOT",
            feeInfo,
            keeper
        );

        vm.stopBroadcast();

        console2.log("SCROLL_SYNCSWAP_USDC_WETH_VAULT=%s", address(syncSwapVault));
    }
}
