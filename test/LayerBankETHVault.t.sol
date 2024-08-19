// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import {ScrollMainnet} from "../config/AddressBook.sol";

import {ICore} from "../src/interfaces/layerbank/ICore.sol";
import {IToken} from "../src/interfaces/layerbank/IToken.sol";

import {LayerBankVault} from "../src/vaults/LayerBankVault.sol";
import {Vault} from "../src/vaults/Vault.sol";
import {ETHVaultHelper} from "../src/helper/ETHVaultHelper.sol";

contract LayerBankETHVaultTest is Test {
    address alice = address(1);

    IERC20 WETH = IERC20(ScrollMainnet.WETH);

    ICore core = ICore(ScrollMainnet.LAYERBANK_CORE);
    IToken iETH = IToken(ScrollMainnet.LAYERBANK_IETH);

    LayerBankVault public vault;
    ETHVaultHelper public ethVaultHelper;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"), 3248043);

        vault = new LayerBankVault(
            WETH,
            "Vault Token",
            "vERC20",
            Vault.FeeInfo(new address[](0), new uint256[](0), 0, 0, 0),
            alice,
            core,
            iETH,
            address(WETH),
            WETH
        );
        ethVaultHelper = new ETHVaultHelper(address(WETH));
    }

    function testDeposit() public {
        uint256 assets = 1 ether;

        ethVaultHelper.depositETH{value: assets}(address(vault), address(this));

        assertApproxEqAbs(vault.balanceOf(address(this)), vault.previewDeposit(assets), 1e18);
    }

    function testWithdraw() public {
        uint256 assets = 1 ether;

        ethVaultHelper.depositETH{value: assets}(address(vault), address(this));
        uint256 balance = address(this).balance;

        vault.approve(address(ethVaultHelper), type(uint256).max);
        ethVaultHelper.withdrawETH(address(vault), assets / 2);

        assertApproxEqAbs(address(this).balance, balance + assets, 1e18);
    }

    receive() external payable {
        console.log("LayerBankETHVaultTest receive ETH:", msg.value);
    }
}
