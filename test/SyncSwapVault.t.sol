// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import {ScrollMainnet} from "../config/AddressBook.sol";

import {IRouter} from "../src/interfaces/syncswap/IRouter.sol";
import {IPool} from "../src/interfaces/syncswap/IPool.sol";

import {SyncSwapVault} from "../src/vaults/SyncSwapVault.sol";
import {Vault} from "../src/vaults/Vault.sol";
import {SyncSwapVaultHelper} from "../src/helper/SyncSwapVaultHelper.sol";

contract SyncSwapVaultTest is Test {
    address alice = address(1);

    IERC20 USDC = IERC20(ScrollMainnet.USDC);
    IERC20 WETH = IERC20(ScrollMainnet.WETH);

    IRouter router = IRouter(ScrollMainnet.SYNCSWAP_ROUTER);
    IPool pool = IPool(ScrollMainnet.SYNCSWAP_USDC_WETH_LP);

    SyncSwapVault public vault;
    SyncSwapVaultHelper public vaultHelper;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"), 3248043);

        vault = new SyncSwapVault(
            IERC20(address(pool)),
            "Vault Token",
            "vUSDCE",
            Vault.FeeInfo(new address[](0), new uint256[](0), 0, 0, 0),
            alice
        );

        vaultHelper = new SyncSwapVaultHelper(router);
    }

    function testDepositUSDC() public {
        uint256 amount = 100 * 1e6;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vaultHelper), amount);

        SyncSwapVaultHelper.TokenInput[] memory inputs = new SyncSwapVaultHelper.TokenInput[](1);
        inputs[0] = SyncSwapVaultHelper.TokenInput(address(USDC), amount);

        uint256 shares = vaultHelper.deposit(inputs, 0, block.timestamp + 180, address(vault), address(this));

        assertEq(shares, vault.balanceOf(address(this)));
    }

    function testDepositETH() public {
        uint256 amount = 1e18;

        SyncSwapVaultHelper.TokenInput[] memory inputs = new SyncSwapVaultHelper.TokenInput[](1);
        inputs[0] = SyncSwapVaultHelper.TokenInput(address(0), amount);

        uint256 shares = vaultHelper.deposit{value: amount}(
            inputs,
            0,
            block.timestamp + 180,
            address(vault),
            address(this)
        );

        assertEq(shares, vault.balanceOf(address(this)));
    }

    function testDespositETHAndUSDC() public {
        uint256 amount = 1e18;
        uint256 usdcAmount = 100 * 1e6;

        deal(address(USDC), address(this), usdcAmount);
        USDC.approve(address(vaultHelper), usdcAmount);

        SyncSwapVaultHelper.TokenInput[] memory inputs = new SyncSwapVaultHelper.TokenInput[](2);
        inputs[0] = SyncSwapVaultHelper.TokenInput(address(0), amount);
        inputs[1] = SyncSwapVaultHelper.TokenInput(address(USDC), usdcAmount);

        uint256 shares = vaultHelper.deposit{value: amount}(
            inputs,
            0,
            block.timestamp + 180,
            address(vault),
            address(this)
        );

        assertEq(shares, vault.balanceOf(address(this)));
    }

    function testDepositUSDCAndETH() public {
        uint256 amount = 1e18;
        uint256 usdcAmount = 100 * 1e6;

        deal(address(USDC), address(this), usdcAmount);
        USDC.approve(address(vaultHelper), usdcAmount);

        SyncSwapVaultHelper.TokenInput[] memory inputs = new SyncSwapVaultHelper.TokenInput[](2);
        inputs[0] = SyncSwapVaultHelper.TokenInput(address(USDC), usdcAmount);
        inputs[1] = SyncSwapVaultHelper.TokenInput(address(0), amount);

        uint256 shares = vaultHelper.deposit{value: amount}(
            inputs,
            0,
            block.timestamp + 180,
            address(vault),
            address(this)
        );

        assertEq(shares, vault.balanceOf(address(this)));
    }

    function testRedeemUSDC() public {
        uint256 amount = 100 * 1e6;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vaultHelper), amount);

        SyncSwapVaultHelper.TokenInput[] memory inputs = new SyncSwapVaultHelper.TokenInput[](1);
        inputs[0] = SyncSwapVaultHelper.TokenInput(address(USDC), amount);

        uint256 shares = vaultHelper.deposit(inputs, 0, block.timestamp + 180, address(vault), address(this));

        vault.approve(address(vaultHelper), shares);
        vaultHelper.redeem(address(vault), address(USDC), shares, 0, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertApproxEqRel(USDC.balanceOf(address(this)), amount, 5 * 1e15); // 0.5%
    }

    function testRedeemETH() public {
        uint256 amount = 1e18;

        SyncSwapVaultHelper.TokenInput[] memory inputs = new SyncSwapVaultHelper.TokenInput[](1);
        inputs[0] = SyncSwapVaultHelper.TokenInput(address(0), amount);

        uint256 shares = vaultHelper.deposit{value: amount}(
            inputs,
            0,
            block.timestamp + 180,
            address(vault),
            address(this)
        );
        uint256 afterDepositBalance = address(this).balance;

        // input WETH address to redeem ETH
        vault.approve(address(vaultHelper), shares);
        vaultHelper.redeem(address(vault), address(WETH), shares, 0, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertApproxEqRel(address(this).balance - afterDepositBalance, amount, 5 * 1e15); // 0.5%
    }

    function testWithdrawUSDC() public {
        uint256 amount = 100 * 1e6;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vaultHelper), amount);

        SyncSwapVaultHelper.TokenInput[] memory inputs = new SyncSwapVaultHelper.TokenInput[](1);
        inputs[0] = SyncSwapVaultHelper.TokenInput(address(USDC), amount);

        uint256 shares = vaultHelper.deposit(inputs, 0, block.timestamp + 180, address(vault), address(this));
        uint256 assets = vault.previewRedeem(shares);

        vault.approve(address(vaultHelper), shares);
        vaultHelper.withdraw(address(vault), address(USDC), assets, 0, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertApproxEqRel(USDC.balanceOf(address(this)), amount, 5 * 1e15);
    }

    function testWithdrawETH() public {
        uint256 amount = 1e18;

        SyncSwapVaultHelper.TokenInput[] memory inputs = new SyncSwapVaultHelper.TokenInput[](1);
        inputs[0] = SyncSwapVaultHelper.TokenInput(address(0), amount);

        uint256 shares = vaultHelper.deposit{value: amount}(
            inputs,
            0,
            block.timestamp + 180,
            address(vault),
            address(this)
        );
        uint256 assets = vault.previewRedeem(shares);
        uint256 afterDepositBalance = address(this).balance;

        // input WETH address to redeem ETH
        vault.approve(address(vaultHelper), shares);
        vaultHelper.withdraw(address(vault), address(WETH), assets, 0, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertApproxEqRel(address(this).balance - afterDepositBalance, amount, 5 * 1e15);
    }

    function testDepositETHRedeemUSDC() public {
        uint256 amount = 1e18;

        SyncSwapVaultHelper.TokenInput[] memory inputs = new SyncSwapVaultHelper.TokenInput[](1);
        inputs[0] = SyncSwapVaultHelper.TokenInput(address(0), amount);

        uint256 shares = vaultHelper.deposit{value: amount}(
            inputs,
            0,
            block.timestamp + 180,
            address(vault),
            address(this)
        );
        uint256 assets = vault.previewRedeem(shares);
        uint256 afterDepositBalance = address(this).balance;

        vault.approve(address(vaultHelper), shares / 2);
        vaultHelper.withdraw(address(vault), address(USDC), assets / 2, 0, address(this));

        uint256 sharesLeft = vault.balanceOf(address(this));

        vault.approve(address(vaultHelper), sharesLeft);
        vaultHelper.redeem(address(vault), address(WETH), sharesLeft, 0, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertApproxEqRel(address(this).balance - afterDepositBalance, amount / 2, 5 * 1e15); // 0.5%
    }

    receive() external payable {}
}
