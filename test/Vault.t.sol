// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import {ScrollMainnet} from "../config/AddressBook.sol";

import {Vault} from "../src/vaults/Vault.sol";

contract VaultTest is Test {
    address alice = address(1);

    struct Rate {
        uint256 rate;
        uint256 timestamp;
    }

    IERC20 USDC = IERC20(ScrollMainnet.USDC);

    Vault public vault;

    address public constant treasury = ScrollMainnet.LO_TREASURY;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"));

        address[] memory recipients = new address[](1);
        recipients[0] = treasury;

        uint256[] memory recipientWeights = new uint256[](1);
        recipientWeights[0] = 1000;

        uint256 _harvesterWeight = 2000;
        uint256 _harvestFeeRate = 2000;
        uint256 _withdrawalFeeRate = 5000;

        vault = new Vault(
            USDC,
            "Vault Token",
            "vUSDC",
            Vault.FeeInfo(recipients, recipientWeights, _harvesterWeight, _harvestFeeRate, _withdrawalFeeRate),
            alice
        );
    }

    function testDecimals() public {
        assertEq(IERC20Metadata(address(USDC)).decimals() + 6, vault.decimals());
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

    function testHarvest() public {
        uint256 amount = 1000000000000000000;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        vm.roll(block.number + 10000);

        vault.harvest(address(this));
    }

    function testWithdraw() public {
        uint256 amount = 1e19;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        vm.roll(block.number + 10000);

        vault.withdraw(amount, address(this), address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(true, USDC.balanceOf(treasury) > 0);
    }

    function testWithdrawalRecipient() public {
        uint256 amount = 1000000000000000000;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        vm.roll(block.number + 10000);

        vault.withdraw(amount, address(this), address(this));

        assertEq(true, USDC.balanceOf(treasury) > 0);
    }

    function testEmergencyWithdraws() public {
        uint256 totalAmount = 1000000000000000000;

        deal(address(USDC), address(this), totalAmount);
        USDC.approve(address(vault), totalAmount);
        vault.deposit(totalAmount, address(this));

        vault.emergencyWithdraw();

        assertEq(vault.paused(), true);
    }

    function testSetFeeInfo() public {
        address newtreasury1 = 0x0000000000000000000000000000000000000000;
        address newtreasury2 = 0x0000000000000000000000000000000000000001;
        address[] memory _recipients = new address[](2);
        _recipients[0] = newtreasury1;
        _recipients[1] = newtreasury2;
        uint256[] memory _recipientWeights = new uint256[](2);
        _recipientWeights[0] = 500;
        _recipientWeights[1] = 500;
        uint256 _harvesterWeight = 1000;
        uint256 _harvestFeeRate = 6000;
        uint256 _withdrawalFeeRate = 3000;

        vault.setFeeInfo(
            Vault.FeeInfo(_recipients, _recipientWeights, _harvesterWeight, _harvestFeeRate, _withdrawalFeeRate)
        );

        (uint256 harvesterWeight, uint256 harvestFeeRate, uint256 withdrawalFeeRate) = vault.feeInfo();

        assertEq(harvesterWeight, _harvesterWeight);
        assertEq(harvestFeeRate, _harvestFeeRate);
        assertEq(withdrawalFeeRate, _withdrawalFeeRate);
    }
}
