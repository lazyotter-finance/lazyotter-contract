// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import {ScrollMainnet} from "../../config/AddressBook.sol";

import {IRErc20Delegator} from "../../src/interfaces/rhoMarkets/IRErc20Delegator.sol";
import {IComptroller} from "../../src/interfaces/rhoMarkets/IComptroller.sol";
import {IREther} from "../../src/interfaces/rhoMarkets/IREther.sol";

import {RhoMarketsVault} from "../../src/vaults/RhoMarketsVault.sol";
import {Vault} from "../../src/vaults/Vault.sol";

contract RhoMarketsVaultTest is Test {
    address alice = address(1);

    IERC20 USDC = IERC20(ScrollMainnet.USDC);

    IRErc20Delegator public RUSDC = IRErc20Delegator(ScrollMainnet.RHO_MARKETS_USDC);
    IREther public RWETH = IREther(ScrollMainnet.RHO_MARKETS_WETH);

    RhoMarketsVault public vault;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"), 7889975);

        vault = new RhoMarketsVault(
            USDC, "Vault Token", "vUSDCE", Vault.FeeInfo(new address[](0), new uint256[](0), 0, 0, 0), alice, RUSDC
        );
    }

    function testDeposit() public {
        uint256 amount = 100 * 1e6;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vault), amount);
        uint256 previewDeposit = vault.previewDeposit(amount);
        vault.deposit(amount, address(this));

        assertEq(vault.balanceOf(address(this)), previewDeposit);
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

    function testMaxWithdraw() public {
        uint256 USDCamount = 1000000 * 1e6;
        deal(address(USDC), address(this), USDCamount);
        USDC.approve(address(vault), USDCamount);
        vault.deposit(USDCamount, address(this));

        uint256 amount = 1000 ether;

        RWETH.mint{value: amount}();

        IComptroller comptroller = IComptroller(RWETH.comptroller());

        address[] memory markets = new address[](1);
        markets[0] = address(RWETH);
        comptroller.enterMarkets(markets);

        RUSDC.borrow(RUSDC.getCash() - 1000);
        assertEq(vault.maxWithdraw(address(this)), 1000);
        RUSDC.borrow(RUSDC.getCash());
        assertEq(vault.maxWithdraw(address(this)), 0);
    }
}
