// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Script.sol";
import {ScrollMainnet} from "../../config/AddressBook.sol";

import {IRErc20Delegator} from "../../src/interfaces/rhoMarkets/IRErc20Delegator.sol";

import {RhoMarketsVault} from "../../src/vaults/RhoMarketsVault.sol";
import {Vault} from "../../src/vaults/Vault.sol";

contract Deploy is Script {
    // TODO: set treasury, keeper addresses
    address treasury = ScrollMainnet.LO_TREASURY;
    address keeper = ScrollMainnet.KEEPER;

    IERC20 USDC = IERC20(ScrollMainnet.USDC);

    IRErc20Delegator public RUSDC = IRErc20Delegator(ScrollMainnet.RHO_MARKETS_USDC);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address[] memory recipients = new address[](1);
        recipients[0] = treasury;

        uint256[] memory recipientWeights = new uint256[](1);
        recipientWeights[0] = 500;

        Vault.FeeInfo memory feeInfo = Vault.FeeInfo(recipients, recipientWeights, 200, 0, 0);

        vm.startBroadcast(deployerPrivateKey);

        RhoMarketsVault rhoMarketsVault = new RhoMarketsVault(
            USDC,
            "LazyOtter: Vault RhoMarkets USDC",
            "LOT",
            feeInfo,
            keeper,
            RUSDC
        );

        vm.stopBroadcast();

        console2.log("SCROLL_RHOMARKETS_USDC_VAULT=%s", address(rhoMarketsVault));
    }
}
