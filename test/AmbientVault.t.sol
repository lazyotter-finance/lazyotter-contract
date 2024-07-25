// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import {ScrollMainnet} from "../config/AddressBook.sol";
import {FixedPoint} from "../src/utils/FixedPoint.sol";

import {ICrocSwapDex} from "../src/interfaces/ambient/ICrocSwapDex.sol";
import {ICrocQuery} from "../src/interfaces/ambient/ICrocQuery.sol";

import {AmbientVault} from "../src/vaults/AmbientVault.sol";
import {Vault} from "../src/vaults/Vault.sol";
import {AmbientVaultHelper} from "../src/helper/AmbientVaultHelper.sol";
import {CrocLpErc20} from "../src/utils/CrocLpErc20.sol";

import "forge-std/console.sol";

contract AmbientVaultTest is Test {
    address alice = address(1);

    IERC20 USDC = IERC20(ScrollMainnet.USDC);
    IERC20 ETH = IERC20(address(0));

    ICrocSwapDex crocSwapDex = ICrocSwapDex(ScrollMainnet.AMBIENT_SWAPDEX);
    ICrocQuery crocQuery = ICrocQuery(ScrollMainnet.AMBIENT_QUERY);

    AmbientVault public vault;
    AmbientVaultHelper public vaultHelper;
    CrocLpErc20 public crocLpErc20;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"), 6864864);

        crocLpErc20 = new CrocLpErc20(crocSwapDex, address(ETH), address(USDC), 420);

        vault = new AmbientVault(
            IERC20(address(crocLpErc20)),
            "Vault Token",
            "vUSDCE",
            Vault.FeeInfo(new address[](0), new uint256[](0), 0, 0, 0),
            alice
        );

        vaultHelper = new AmbientVaultHelper(crocSwapDex, crocQuery);
    }

    function testDepositUSDC() public {
        uint256 amount = 3000 * 1e6;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vaultHelper), amount);

        AmbientVaultHelper.TokenInput[] memory inputs = new AmbientVaultHelper.TokenInput[](1);
        inputs[0] = AmbientVaultHelper.TokenInput(address(USDC), amount);

        uint128 price = crocQuery.queryPrice(address(0), address(USDC), 420);
        uint128 limit = price * 5 / 100;
        AmbientVaultHelper.LimitPrice memory limitPrice = AmbientVaultHelper.LimitPrice(price - limit, price + limit);

        uint128 minOut = 1;

        uint256 shares = vaultHelper.deposit(inputs, limitPrice, minOut, address(vault), address(this));

        assertEq(shares, vault.balanceOf(address(this)));
    }

    function testDepositETH() public {
        uint256 amount = 1 ether;
        deal(address(this), amount);

        AmbientVaultHelper.TokenInput[] memory inputs = new AmbientVaultHelper.TokenInput[](1);
        inputs[0] = AmbientVaultHelper.TokenInput(address(0), amount);

        uint128 price = crocQuery.queryPrice(address(0), address(USDC), 420);
        uint128 limit = price * 5 / 100;
        AmbientVaultHelper.LimitPrice memory limitPrice = AmbientVaultHelper.LimitPrice(price - limit, price + limit);

        uint128 minOut = 1;

        uint256 shares = vaultHelper.deposit{value: 1 ether}(inputs, limitPrice, minOut, address(vault), address(this));

        assertEq(shares, vault.balanceOf(address(this)));
    }

    function testDespositETHAndUSDC() public {
        uint256 amount = 1e18;
        uint256 usdcAmount = 100 * 1e6;

        deal(address(USDC), address(this), usdcAmount);
        USDC.approve(address(vaultHelper), usdcAmount);

        AmbientVaultHelper.TokenInput[] memory inputs = new AmbientVaultHelper.TokenInput[](2);
        inputs[0] = AmbientVaultHelper.TokenInput(address(0), amount);
        inputs[1] = AmbientVaultHelper.TokenInput(address(USDC), usdcAmount);

        uint128 price = crocQuery.queryPrice(address(0), address(USDC), 420);
        uint128 limit = price * 5 / 100;
        AmbientVaultHelper.LimitPrice memory limitPrice = AmbientVaultHelper.LimitPrice(price - limit, price + limit);

        uint128 minOut = 1;

        uint256 shares = vaultHelper.deposit{value: amount}(inputs, limitPrice, minOut, address(vault), address(this));
        vaultHelper.previewAmountByShare(address(vault), shares);

        assertEq(shares, vault.balanceOf(address(this)));
    }

    function testDepositUSDCAndETH() public {
        uint256 amount = 1e18;
        uint256 usdcAmount = 100 * 1e6;

        deal(address(USDC), address(this), usdcAmount);
        USDC.approve(address(vaultHelper), usdcAmount);

        AmbientVaultHelper.TokenInput[] memory inputs = new AmbientVaultHelper.TokenInput[](2);
        inputs[0] = AmbientVaultHelper.TokenInput(address(USDC), usdcAmount);
        inputs[1] = AmbientVaultHelper.TokenInput(address(0), amount);

        uint128 price = crocQuery.queryPrice(address(0), address(USDC), 420);
        uint128 limit = price * 5 / 100;
        AmbientVaultHelper.LimitPrice memory limitPrice = AmbientVaultHelper.LimitPrice(price - limit, price + limit);

        uint128 minOut = 1;

        uint256 shares = vaultHelper.deposit{value: amount}(inputs, limitPrice, minOut, address(vault), address(this));

        assertEq(shares, vault.balanceOf(address(this)));
    }

    function testRedeemUSDCandETH() public {
        deal(address(this), 1e9 wei);

        uint256 amount = 100 * 1e6;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vaultHelper), amount);

        AmbientVaultHelper.TokenInput[] memory inputs = new AmbientVaultHelper.TokenInput[](1);
        inputs[0] = AmbientVaultHelper.TokenInput(address(USDC), amount);

        uint128 price = crocQuery.queryPrice(address(0), address(USDC), 420);
        uint128 limit = price * 5 / 100;
        AmbientVaultHelper.LimitPrice memory limitPrice = AmbientVaultHelper.LimitPrice(price - limit, price + limit);

        uint128 minOut = 1;

        uint256 shares = vaultHelper.deposit(inputs, limitPrice, minOut, address(vault), address(this));

        vault.approve(address(vaultHelper), shares);
        (uint256 quoteTokenAmount, uint256 baseTokenAmount) =
            vaultHelper.redeem(limitPrice, address(vault), shares, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertApproxEqRel(address(this).balance, baseTokenAmount, 5 * 1e15); // 0.5%
        assertApproxEqRel(USDC.balanceOf(address(this)), quoteTokenAmount, 5 * 1e15); // 0.5%
    }

    function testRedeemUSDC() public {
        uint256 amount = 1 ether;
        deal(address(this), amount);

        AmbientVaultHelper.TokenInput[] memory inputs = new AmbientVaultHelper.TokenInput[](1);
        inputs[0] = AmbientVaultHelper.TokenInput(address(0), amount);

        uint128 price = crocQuery.queryPrice(address(0), address(USDC), 420);
        uint128 limit = price * 5 / 100;
        AmbientVaultHelper.LimitPrice memory limitPrice = AmbientVaultHelper.LimitPrice(price - limit, price + limit);

        uint128 minOut = 1;
        AmbientVaultHelper.RemoveLiquidityParams memory params = AmbientVaultHelper.RemoveLiquidityParams(false, minOut);

        uint256 shares = vaultHelper.deposit{value: amount}(inputs, limitPrice, minOut, address(vault), address(this));

        vault.approve(address(vaultHelper), shares);
        uint256 receiveAmount = vaultHelper.redeemSingle(limitPrice, params, address(vault), shares, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(USDC.balanceOf(address(this)), receiveAmount);
    }

    function testRedeemETH() public {
        uint256 amount = 1 ether;
        deal(address(this), amount);

        AmbientVaultHelper.TokenInput[] memory inputs = new AmbientVaultHelper.TokenInput[](1);
        inputs[0] = AmbientVaultHelper.TokenInput(address(0), amount);

        uint128 price = crocQuery.queryPrice(address(0), address(USDC), 420);
        uint128 limit = price * 5 / 100;
        AmbientVaultHelper.LimitPrice memory limitPrice = AmbientVaultHelper.LimitPrice(price - limit, price + limit);

        uint128 minOut = 1;
        AmbientVaultHelper.RemoveLiquidityParams memory params = AmbientVaultHelper.RemoveLiquidityParams(true, minOut);

        uint256 shares = vaultHelper.deposit{value: amount}(inputs, limitPrice, minOut, address(vault), address(this));

        vault.approve(address(vaultHelper), shares);
        uint256 receiveAmount = vaultHelper.redeemSingle(limitPrice, params, address(vault), shares, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertApproxEqRel(address(this).balance, receiveAmount, 5 * 1e15); // 0.5%
    }

    function testWithdrawUSDCandETH() public {
        deal(address(this), 1e9 wei);

        uint256 amount = 1000 * 1e6;
        deal(address(USDC), address(this), amount);
        USDC.approve(address(vaultHelper), amount);

        AmbientVaultHelper.TokenInput[] memory inputs = new AmbientVaultHelper.TokenInput[](1);
        inputs[0] = AmbientVaultHelper.TokenInput(address(USDC), amount);

        uint128 price = crocQuery.queryPrice(address(0), address(USDC), 420);
        uint128 limit = price * 5 / 100;
        AmbientVaultHelper.LimitPrice memory limitPrice = AmbientVaultHelper.LimitPrice(price - limit, price + limit);

        uint128 minOut = 1;

        uint256 shares = vaultHelper.deposit(inputs, limitPrice, minOut, address(vault), address(this));
        uint256 assets = vaultHelper.previewRedeem(address(vault), shares);

        (uint256 quoteTokenAmountByAsset,) = vaultHelper.previewAmountByAsset(address(vault), assets);
        (uint256 quoteTokenAmountByShare,) = vaultHelper.previewAmountByShare(address(vault), shares);
        assertEq(quoteTokenAmountByAsset, quoteTokenAmountByShare);

        uint256 UsdcBalanceAfterDeposit = USDC.balanceOf(address(this));

        vault.approve(address(vaultHelper), shares);
        (uint256 quoteTokenAmount, uint256 baseTokenAmount) =
            vaultHelper.withdraw(limitPrice, address(vault), assets, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(USDC.balanceOf(address(this)) - UsdcBalanceAfterDeposit, quoteTokenAmountByAsset);
        assertApproxEqRel(USDC.balanceOf(address(this)), amount / 2, 2 * 1e16); // 2%
        assertApproxEqRel(address(this).balance, baseTokenAmount, 5 * 1e15); // 0.5%
        assertApproxEqRel(USDC.balanceOf(address(this)), quoteTokenAmount, 5 * 1e15); // 0.5%
    }

    function testWithdrawUSDC() public {
        uint256 amount = 1 ether;
        deal(address(this), amount);

        AmbientVaultHelper.TokenInput[] memory inputs = new AmbientVaultHelper.TokenInput[](1);
        inputs[0] = AmbientVaultHelper.TokenInput(address(0), amount);

        uint128 price = crocQuery.queryPrice(address(0), address(USDC), 420);
        uint128 limit = price * 5 / 100;
        AmbientVaultHelper.LimitPrice memory limitPrice = AmbientVaultHelper.LimitPrice(price - limit, price + limit);

        uint128 minOut = 1;

        uint256 shares = vaultHelper.deposit{value: amount}(inputs, limitPrice, minOut, address(vault), address(this));
        uint256 assets = vaultHelper.previewRedeem(address(vault), shares);

        AmbientVaultHelper.RemoveLiquidityParams memory params = AmbientVaultHelper.RemoveLiquidityParams(false, minOut);

        vault.approve(address(vaultHelper), shares);
        uint256 receiveAmount = vaultHelper.withdrawSingle(limitPrice, params, address(vault), assets, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(USDC.balanceOf(address(this)), receiveAmount);
    }

    function testWithdrawETH() public {
        uint256 amount = 1 ether;
        deal(address(this), amount);

        AmbientVaultHelper.TokenInput[] memory inputs = new AmbientVaultHelper.TokenInput[](1);
        inputs[0] = AmbientVaultHelper.TokenInput(address(0), amount);

        uint128 price = crocQuery.queryPrice(address(0), address(USDC), 420);
        uint128 limit = price * 5 / 100;
        AmbientVaultHelper.LimitPrice memory limitPrice = AmbientVaultHelper.LimitPrice(price - limit, price + limit);

        uint128 minOut = 1;

        uint256 shares = vaultHelper.deposit{value: amount}(inputs, limitPrice, minOut, address(vault), address(this));
        uint256 assets = vaultHelper.previewRedeem(address(vault), shares);

        AmbientVaultHelper.RemoveLiquidityParams memory params = AmbientVaultHelper.RemoveLiquidityParams(true, minOut);

        vault.approve(address(vaultHelper), shares);
        uint256 receiveAmount = vaultHelper.withdrawSingle(limitPrice, params, address(vault), assets, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertApproxEqRel(address(this).balance, receiveAmount, 5 * 1e15); // 0.5%
    }

    receive() external payable {}

    fallback() external payable {}
}
