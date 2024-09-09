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

    IERC20 wstETH = IERC20(ScrollMainnet.wstETH);
    IERC20 WETH = IERC20(ScrollMainnet.WETH);

    ICore core = ICore(ScrollMainnet.LAYERBANK_CORE);
    IToken iWSTETH = IToken(ScrollMainnet.LAYERBANK_IWSTETH);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address[] memory recipients = new address[](1);
        recipients[0] = treasury;

        uint256[] memory recipientWeights = new uint256[](1);
        recipientWeights[0] = 500;

        Vault.FeeInfo memory feeInfo = Vault.FeeInfo(recipients, recipientWeights, 200, 0, 0);

        vm.startBroadcast(deployerPrivateKey);

        LayerBankVault layerBankVault = new LayerBankVault(
            wstETH, "LazyOtter: Vault LayerBank wstETH", "LOT", feeInfo, keeper, core, iWSTETH, address(WETH), WETH
        );

        vm.stopBroadcast();

        console2.log("SCROLL_LAYERBANK_WSTETH_VAULT=%s", address(layerBankVault));
    }
}
