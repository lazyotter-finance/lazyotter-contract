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
import {ETHVaultHelper} from "../src/helper/ETHVaultHelper.sol";

contract ETHVaultHelperTest is Test {
    address alice = address(1);

    IERC20 WETH = IERC20(ScrollMainnet.WETH);

    IDataProvider dataProvider = IDataProvider(ScrollMainnet.AAVE_DATAPROVIDER);
    ILendingPool lendingPool = ILendingPool(ScrollMainnet.AAVE_LENDINGPOOL);
    IRewardsController rewardsController = IRewardsController(ScrollMainnet.AAVE_REWARDSCONTROLLER);
    ISwapRouter public swapRouter = ISwapRouter(ScrollMainnet.UNISWAP_SWAPROUTER);
    IUniswapV3Factory public factory = IUniswapV3Factory(ScrollMainnet.UNISWAP_FACTORY);

    AaveVault public vault;
    ETHVaultHelper public ethVaultHelper;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"), 3248043);

        vault = new AaveVault(
            WETH,
            "Vault Token",
            "vWETH",
            Vault.FeeInfo(new address[](0), new uint256[](0), 0, 0, 0),
            alice,
            dataProvider,
            lendingPool,
            rewardsController,
            swapRouter,
            factory,
            WETH
        );

        ethVaultHelper = new ETHVaultHelper(address(WETH));
    }

    function testDepositETH() public {
        uint256 assets = 1 ether;
        uint256 shares = vault.previewDeposit(assets);

        ethVaultHelper.depositETH{value: assets}(address(vault), address(this));

        assertEq(vault.balanceOf(address(this)), shares);
    }

    function testMintETH() public {
        uint256 shares = 1e18;
        uint256 assets = vault.previewMint(shares);

        ethVaultHelper.mintETH{value: assets}(address(vault), shares, address(this));

        assertEq(vault.balanceOf(address(this)), shares);
    }

    function testMintETHRefund() public {
        uint256 shares = 1e24;
        uint256 assets = vault.previewMint(shares);
        uint256 balance = address(this).balance;

        ethVaultHelper.mintETH{value: assets + 1 ether}(address(vault), shares, address(this));

        assertEq(vault.balanceOf(address(this)), shares);
        assertEq(address(this).balance, balance - assets);
    }

    function testWithdrawETH() public {
        uint256 assets = 1 ether;

        ethVaultHelper.depositETH{value: assets}(address(vault), address(this));
        uint256 balance = address(this).balance;

        vault.approve(address(ethVaultHelper), type(uint256).max);
        ethVaultHelper.withdrawETH(address(vault), assets);

        assertEq(address(this).balance, balance + assets);
    }

    function testRedeemETH() public {
        uint256 shares = 1e18;
        uint256 assets = vault.previewRedeem(shares);

        ethVaultHelper.depositETH{value: assets}(address(vault), address(this));
        uint256 balance = address(this).balance;

        vault.approve(address(ethVaultHelper), type(uint256).max);
        ethVaultHelper.redeemETH(address(vault), shares);

        assertEq(address(this).balance, balance + assets);
    }

    receive() external payable {}

    fallback() external payable {}
}
