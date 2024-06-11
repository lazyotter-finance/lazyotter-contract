// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import {ScrollMainnet} from "../config/AddressBook.sol";

import {ICore} from "../src/interfaces/layerbank/ICore.sol";
import {IToken} from "../src/interfaces/layerbank/IToken.sol";

import {LayerBankVault} from "../src/vaults/LayerBankVault.sol";
import {Vault} from "../src/vaults/Vault.sol";

contract LayerBankVaultTest is Test {
    address alice = address(1);

    IERC20 USDC = IERC20(ScrollMainnet.USDC);
    IERC20 WETH = IERC20(ScrollMainnet.WETH);

    ICore core = ICore(ScrollMainnet.LAYERBANK_CORE);
    IToken iUSDC = IToken(ScrollMainnet.LAYERBANK_IUSDC);

    LayerBankVault public vault;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"), 3248043);

        vault = new LayerBankVault(
            USDC,
            "Vault Token",
            "vUSDCE",
            Vault.FeeInfo(new address[](0), new uint256[](0), 0, 0, 0),
            alice,
            core,
            iUSDC,
            WETH
        );
    }

    function testDeposit() public {
        uint256 amount = 100 * 1e6;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        // why minus 1e6 is because layerbank return the rounding result to user
        assertApproxEqAbs(vault.balanceOf(address(this)), vault.previewDeposit(amount), 1e6);
    }

    function testWithdraw() public {
        uint256 amount = 100 * 1e6;
        uint256 amount1 = 200 * 1e6;

        deal(address(USDC), address(this), amount + amount1);

        USDC.approve(address(vault), amount);
        vault.deposit(amount, address(this));
        USDC.approve(address(vault), amount1);
        vault.deposit(amount1, address(this));

        // withdraw 100
        vault.withdraw(amount, address(this), address(this));
        assertEq(USDC.balanceOf(address(this)), amount);

        // withdraw almost all 200 - 1e6
        vault.withdraw(amount1 - 1e6, address(this), address(this));
        assertApproxEqAbs(USDC.balanceOf(address(this)) - amount, amount1, 1e6);

        // the last 1e6 would be unable to withdraw, vault keeper need to be the last one
        //vault.withdraw(1e6, address(this), address(this));
    }

    function testEmergencyWithdraws() public {
        uint256 totalAmount = 100 * 1e6;
        uint256 halfAmount = totalAmount / 2;

        deal(address(USDC), address(this), totalAmount);
        USDC.approve(address(vault), totalAmount);
        vault.deposit(totalAmount, address(this));

        vault.emergencyWithdraw(halfAmount);
        assertEq(vault.paused(), true);
        assertEq(USDC.balanceOf(address(vault)), halfAmount);

        vault.unpause();
        vault.emergencyWithdraw();
        assertApproxEqAbs(USDC.balanceOf(address(vault)), totalAmount, 1e6);
        assertEq(vault.paused(), true);
    }
}
