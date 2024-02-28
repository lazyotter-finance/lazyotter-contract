// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import {ScrollMainnet} from "../config/AddressBook.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IRewardsController} from "../src/interfaces/aave/IRewardsController.sol";
import {IDataProvider} from "../src/interfaces/aave/IDataProvider.sol";
import {ILendingPool} from "../src/interfaces/aave/ILendingPool.sol";

import {AaveVault} from "../src/vaults/AaveVault.sol";
import {Vault} from "../src/vaults/Vault.sol";

contract AaveVaultTest is Test {
    address alice = address(1);

    IERC20 USDC = IERC20(ScrollMainnet.USDC);
    IERC20 WETH = IERC20(ScrollMainnet.WETH);

    IDataProvider dataProvider = IDataProvider(ScrollMainnet.AAVE_DATAPROVIDER);
    ILendingPool lendingPool = ILendingPool(ScrollMainnet.AAVE_LENDINGPOOL);
    IRewardsController rewardsController = IRewardsController(ScrollMainnet.AAVE_REWARDSCONTROLLER);
    ISwapRouter public swapRouter = ISwapRouter(ScrollMainnet.UNISWAP_SWAPROUTER);
    IUniswapV3Factory public factory = IUniswapV3Factory(ScrollMainnet.UNISWAP_FACTORY);

    AaveVault public vault;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"), 3248043);

        vault = new AaveVault(
            USDC,
            "Vault Token",
            "vUSDCE",
            Vault.FeeInfo(new address[](0), new uint256[](0), 0, 0, 0),
            alice,
            dataProvider,
            lendingPool,
            rewardsController,
            swapRouter,
            factory,
            WETH
        );
    }

    function testDeposit() public {
        uint256 amount = 100 * 1e6;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        assertEq(vault.balanceOf(address(this)), vault.previewDeposit(amount));
    }

    // function testHarvest() public {
    //     uint256 amount = 10000 * 1e6;
    //     deal(address(USDC), address(this), amount);

    //     USDC.approve(address(vault), amount);
    //     vault.deposit(amount, address(this));

    //     skip(30 days);

    //     vault.harvest(address(this));
    // }

    function testWithdraw() public {
        uint256 amount = 100 * 1e6;
        deal(address(USDC), address(this), amount);

        USDC.approve(address(vault), amount);
        vault.deposit(amount, address(this));

        vault.withdraw(amount, address(this), address(this));
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(USDC.balanceOf(address(this)), amount);
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
