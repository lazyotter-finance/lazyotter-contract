// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import {ScrollMainnet} from "../../../config/AddressBook.sol";

import {Vault} from "../../../src/vaultsUpgradable/v1/Vault.sol";
import {Beacon} from "../../../src/vaultsUpgradable/Beacon.sol";
import {Proxy} from "../../../src/vaultsUpgradable/Proxy.sol";

contract VaultUpgradableTest is Test {
    address alice = address(1);

    IERC20 USDC = IERC20(ScrollMainnet.USDC);

    Vault public vault;
    Beacon public beacon;
    Proxy public proxy;

    address public constant treasury = ScrollMainnet.LO_TREASURY;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"));

        // Deploy the implementation contract
        Vault vaultImplementation = new Vault();

        // Deploy the UpgradeableBeacon
        beacon = new Beacon(address(vaultImplementation));

        // Prepare initialization data for the vault
        bytes memory initData = abi.encodeCall(Vault.initialize, (USDC, "Vault Token", "vUSDC", alice));

        // Deploy the BeaconProxy
        proxy = new Proxy(address(beacon), initData);

        // Set the vault variable to point to the proxy
        vault = Vault(address(proxy));
    }

    function testDecimals() public {
        // Get the decimals of the underlying asset (USDC)
        uint8 assetDecimals = IERC20Metadata(address(USDC)).decimals();

        // Get the decimals of the vault token
        uint8 vaultDecimals = vault.decimals();
        assertEq(vaultDecimals, assetDecimals + 6);
    }

    function testAdminAndKeeper() public {
        assertEq(vault.hasRole(0x00, address(this)), true);
        assertEq(vault.hasRole(keccak256("KEEPER_ROLE"), alice), true);
    }

    function testMaxDeposit() public {
        assertEq(type(uint256).max, vault.maxDeposit(address(vault)));
    }

    function testMaxMint() public {
        assertEq(type(uint256).max, vault.maxMint(address(vault)));
    }

    function testMaxWithdraw() public {
        uint256 maxWithdraw = vault.maxWithdraw(address(vault));
        assertEq(maxWithdraw, vault.maxWithdraw(address(vault)));
    }

    function testMaxRedeem() public {
        assertEq(vault.balanceOf(address(vault)), vault.maxRedeem(address(vault)));
    }

    function testDeposit() public {
        uint256 amount = 1000000000000000000;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        assertEq(vault.balanceOf(address(this)), vault.previewDeposit(amount));
    }

    function testWithdraw() public {
        uint256 amount = 1e19;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        vault.withdraw(amount, address(this), address(this));

        assertEq(vault.balanceOf(address(this)), 0);

        /* test fee, but no fee is set yet */
        // assertEq(true, USDC.balanceOf(treasury) > 0);
    }

    function testEmergencyWithdraw() public {
        uint256 totalAmount = 1000000000000000000;

        deal(address(USDC), address(this), totalAmount);
        USDC.approve(address(vault), totalAmount);
        vault.deposit(totalAmount, address(this));

        vault.emergencyWithdraw();

        assertEq(vault.paused(), true);
    }
}
