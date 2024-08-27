// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import {ScrollMainnet} from "../../../config/AddressBook.sol";

import {IDataProvider} from "../../../src/interfaces/aave/IDataProvider.sol";
import {ILendingPool} from "../../../src/interfaces/aave/ILendingPool.sol";

import {AaveVault} from "../../../src/vaultsUpgradable/v1/AaveVault.sol";
import {Beacon} from "../../../src/vaultsUpgradable/Beacon.sol";
import {Proxy} from "../../../src/vaultsUpgradable/Proxy.sol";

contract AaveVaultTest is Test {
    address alice = address(1);

    IERC20 USDC = IERC20(ScrollMainnet.USDC);
    IERC20 aScrUSDC = IERC20(ScrollMainnet.aScrUSDC);
    IDataProvider dataProvider = IDataProvider(ScrollMainnet.AAVE_DATAPROVIDER);
    ILendingPool lendingPool = ILendingPool(ScrollMainnet.AAVE_LENDINGPOOL);

    AaveVault public vault;
    Beacon public beacon;
    Proxy public proxy;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"), 3248043);

        // Deploy the implementation contract
        AaveVault vaultImplementation = new AaveVault();

        // Deploy the UpgradeableBeacon
        beacon = new Beacon(address(vaultImplementation));

        // Prepare initialization data for the vault
        bytes memory initData = abi.encodeCall(
            AaveVault.initialize, (USDC, "Vault Token", "vUSDC", alice, dataProvider, lendingPool)
        );

        // Deploy the BeaconProxy
        proxy = new Proxy(address(beacon), initData);

        // Set the vault variable to point to the proxy
        vault = AaveVault(address(proxy));
    }

    function testTotalAssets() public {
        uint256 totalAssets = vault.totalAssets();
        assertEq(totalAssets, 0);
    }

    function testDeposit() public {
        uint256 amount = 100 * 1e6;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        assertEq(vault.balanceOf(address(this)), vault.previewDeposit(amount));
        assertEq(aScrUSDC.balanceOf(address(vault)), amount);
    }

    function testWithdraw() public {
        uint256 amount = 100 * 1e6;
        deal(address(USDC), address(this), amount);

        USDC.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        vault.withdraw(amount, address(this), address(this));
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(USDC.balanceOf(address(this)), amount);
        assertEq(aScrUSDC.balanceOf(address(vault)), 0);
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
        assertEq(USDC.balanceOf(address(vault)), totalAmount);
        assertEq(vault.paused(), true);
    }
}
