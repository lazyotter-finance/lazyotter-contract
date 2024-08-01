// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Script.sol";
import {ScrollMainnet} from "../../config/AddressBook.sol";

import {ICrocSwapDex} from "../../src/interfaces/ambient/ICrocSwapDex.sol";

import {AmbientVaultHelper} from "../../src/helper/AmbientVaultHelper.sol";
import {AmbientVault} from "../../src/vaults/AmbientVault.sol";
import {Vault} from "../../src/vaults/Vault.sol";
import {CrocLpErc20} from "../../src/utils/CrocLpErc20.sol";

contract Deploy is Script {
    // TODO: set treasury, keeper addresses
    address treasury = ScrollMainnet.LO_TREASURY;
    address keeper = ScrollMainnet.KEEPER;

    ICrocSwapDex crocSwapDex = ICrocSwapDex(ScrollMainnet.AMBIENT_SWAPDEX);
    IERC20 USDC = IERC20(ScrollMainnet.USDC);
    IERC20 ETH = IERC20(address(0));

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address[] memory recipients = new address[](1);
        recipients[0] = treasury;

        uint256[] memory recipientWeights = new uint256[](1);
        recipientWeights[0] = 500;

        Vault.FeeInfo memory feeInfo = Vault.FeeInfo(recipients, recipientWeights, 200, 0, 0);

        vm.startBroadcast(deployerPrivateKey);

        CrocLpErc20 crocLpErc20 = new CrocLpErc20(crocSwapDex, address(ETH), address(USDC), 420);

        AmbientVault ambientVault = new AmbientVault(
            IERC20(address(crocLpErc20)),
            "LazyOtter: Vault AMBIENT USDC ETH",
            "LOT",
            feeInfo,
            keeper
        );

        vm.stopBroadcast();

        console2.log("SCROLL_SYNCSWAP_USDC_WETH_VAULT=%s", address(ambientVault));
    }
}
