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
import {ETHVaultHelper} from "../../../src/helper/ETHVaultHelper.sol";

contract RhoMarketsVaultTest is Test {
    address alice = address(1);

    IERC20 public WETH = IERC20(ScrollMainnet.WETH);
    IRErc20Delegator public RETH = IRErc20Delegator(ScrollMainnet.RHO_MARKETS_RETH);

    RhoMarketsVault public vault;
    Beacon public beacon;
    Proxy public proxy;
    ETHVaultHelper public helper;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"), 9160779);

        // Deploy the implementation contract
        RhoMarketsVault vaultImplementation = new RhoMarketsVault();

        // Deploy the UpgradeableBeacon
        beacon = new Beacon(address(vaultImplementation));

        // Prepare initialization data for the vault
        bytes memory initData = abi.encodeCall(RhoMarketsVault.initialize, (WETH, "Vault Token", "vETH", alice, RETH));

        // Deploy the BeaconProxy
        proxy = new Proxy(address(beacon), initData);

        // Set the vault variable to point to the proxy
        vault = RhoMarketsVault(payable(address(proxy)));

        // deploy eth helper
        helper = new ETHVaultHelper(ScrollMainnet.WETH);
    }

    function testDeposit() public {
        uint256 amount = 1 ether;
        deal(address(this), amount);

        uint256 previewDeposit = vault.previewDeposit(amount);
        helper.depositETH{value: amount}(address(vault), address(this));

        assertEq(vault.balanceOf(address(this)), previewDeposit);
    }

    function testWithdraw() public {
        uint256 amount = 1 ether;
        deal(address(this), amount);
        uint256 previewDeposit = vault.previewDeposit(amount);
        helper.depositETH{value: amount}(address(vault), address(this));

        assertEq(vault.balanceOf(address(this)), previewDeposit);

        vault.approve(address(helper), previewDeposit);
        uint256 withdrawAmount = vault.previewRedeem(previewDeposit);
        helper.withdrawETH(address(vault), withdrawAmount);

        assertApproxEqAbs(address(this).balance, withdrawAmount, 1);
    }

    function testRedeem() public {
        uint256 amount = 1 ether;
        deal(address(this), amount);
        uint256 previewDeposit = vault.previewDeposit(amount);
        helper.depositETH{value: amount}(address(vault), address(this));

        assertEq(vault.balanceOf(address(this)), previewDeposit);

        uint256 shares = vault.balanceOf(address(this));
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

        deal(address(this), totalAmount);
        helper.depositETH{value: totalAmount}(address(vault), address(this));

        vault.emergencyWithdraw(halfAmount);
        assertEq(vault.paused(), true);
        assertApproxEqAbs(WETH.balanceOf(address(vault)), halfAmount, 1);

        vault.unpause();
        vault.emergencyWithdraw();
        assertApproxEqAbs(WETH.balanceOf(address(vault)), totalAmount, 5);
        assertEq(vault.paused(), true);
    }

    receive() external payable {}
}
