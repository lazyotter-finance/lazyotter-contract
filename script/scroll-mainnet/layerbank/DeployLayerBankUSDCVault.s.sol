// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Script.sol";
import {ScrollMainnet} from "../../../config/AddressBook.sol";

import {ICore} from "../../../src/interfaces/layerbank/ICore.sol";
import {IToken} from "../../../src/interfaces/layerbank/IToken.sol";

import {LayerBankVault} from "../../../src/vaults/LayerBankVault.sol";
import {Vault} from "../../../src/vaults/Vault.sol";

contract Deploy is Script {
    // TODO: set treasury, keeper addresses
    address treasury = ScrollMainnet.LO_TREASURY;
    address keeper = ScrollMainnet.KEEPER;

    IERC20 USDC = IERC20(ScrollMainnet.USDC);
    IERC20 WETH = IERC20(ScrollMainnet.WETH);

    ICore core = ICore(ScrollMainnet.LAYERBANK_CORE);
    IToken iUSDC = IToken(ScrollMainnet.LAYERBANK_IUSDC);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address[] memory recipients = new address[](1);
        recipients[0] = treasury;

        uint256[] memory recipientWeights = new uint256[](1);
        recipientWeights[0] = 500;

        Vault.FeeInfo memory feeInfo = Vault.FeeInfo(recipients, recipientWeights, 200, 0, 0);

        vm.startBroadcast(deployerPrivateKey);

        LayerBankVault layerBankVault = new LayerBankVault(
            USDC,
            "LazyOtter: Vault LayerBank USDC",
            "LOT",
            feeInfo,
            keeper,
            core,
            iUSDC,
            address(WETH),
            WETH
        );

        vm.stopBroadcast();

        console2.log("SCROLL_LAYERBANK_USDC_VAULT=%s", address(layerBankVault));
    }
}
