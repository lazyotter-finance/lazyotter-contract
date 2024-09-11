// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import {ScrollMainnet} from "../../../config/AddressBook.sol";

import {IRErc20Delegator} from "../../../src/interfaces/rhoMarkets/IRErc20Delegator.sol";
import {IComptroller} from "../../../src/interfaces/rhoMarkets/IComptroller.sol";
import {IREther} from "../../../src/interfaces/rhoMarkets/IREther.sol";

import {RhoMarketsVault} from "../../../src/vaultsUpgradable/v1/RhoMarketsVault.sol";
import {Beacon} from "../../../src/vaultsUpgradable/Beacon.sol";
import {Proxy} from "../../../src/vaultsUpgradable/Proxy.sol";

contract RhoMarketsVaultTest is Test {
    address alice = address(1);

    IERC20 weETH = IERC20(ScrollMainnet.weETH);

    IRErc20Delegator public RweETH = IRErc20Delegator(ScrollMainnet.RHO_MARKETS_RweETH);

    RhoMarketsVault public vault;
    Beacon public beacon;
    Proxy public proxy;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"), 9160779);

        // Deploy the implementation contract
        RhoMarketsVault vaultImplementation = new RhoMarketsVault();

        // Deploy the UpgradeableBeacon
        beacon = new Beacon(address(vaultImplementation));

        // Prepare initialization data for the vault
        bytes memory initData = abi.encodeCall(
            RhoMarketsVault.initialize,
            (weETH, "Vault Token", "vweETH", alice, RweETH)
        );

        // Deploy the BeaconProxy
        proxy = new Proxy(address(beacon), initData);

        // Set the vault variable to point to the proxy
        vault = RhoMarketsVault(address(proxy));
    }

    function testDeposit() public {
        uint256 amount = 1 ether;
        deal(address(weETH), address(this), amount);
        weETH.approve(address(vault), amount);
        uint256 previewDeposit = vault.previewDeposit(amount);
        vault.deposit(amount, address(this));

        assertEq(vault.balanceOf(address(this)), previewDeposit);
    }

    function testWithdraw() public {
        uint256 amount = 1 ether;
        deal(address(weETH), address(this), amount);
        weETH.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, address(this));

        uint256 withdrawAmount = vault.previewRedeem(shares);
        vault.withdraw(withdrawAmount, address(this), address(this));

        assertApproxEqAbs(weETH.balanceOf(address(this)), withdrawAmount, 1);
    }

    function testRedeem() public {
        uint256 amount = 1 ether;
        deal(address(weETH), address(this), amount);
        weETH.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, address(this));

        if (shares > vault.maxRedeem(address(this))) {
            vault.redeem(vault.maxRedeem(address(this)), address(this), address(this));
        } else {
            vault.redeem(shares, address(this), address(this));
        }

        assertApproxEqAbs(vault.balanceOf(address(this)), 0, 1);
    }

    function testEmergencyWithdraws() public {
        uint256 totalAmount = 1 ether;
        uint256 halfAmount = totalAmount / 2;

        deal(address(weETH), address(this), totalAmount);
        weETH.approve(address(vault), totalAmount);
        vault.deposit(totalAmount, address(this));

        vault.emergencyWithdraw(halfAmount);
        assertEq(vault.paused(), true);
        assertApproxEqAbs(weETH.balanceOf(address(vault)), halfAmount, 1);

        vault.unpause();
        vault.emergencyWithdraw();
        assertApproxEqAbs(weETH.balanceOf(address(vault)), totalAmount, 5);
        assertEq(vault.paused(), true);
    }
}
