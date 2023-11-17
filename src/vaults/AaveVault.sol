// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IRewardsController} from "../interfaces/aave/IRewardsController.sol";
import {IDataProvider} from "../interfaces/aave/IDataProvider.sol";
import {ILendingPool} from "../interfaces/aave/ILendingPool.sol";

import {UniswapHelper} from "../utils/UniswapHelper.sol";
import {Vault} from "./Vault.sol";

contract AaveVault is Vault {
    using SafeERC20 for IERC20;

    // Tokens used
    IERC20 public native;
    IERC20 public aToken;

    // Third party contracts
    IDataProvider public dataProvider;
    ILendingPool public lendingPool;
    IRewardsController public rewardsController;
    IUniswapV3Factory public immutable factory;
    ISwapRouter public immutable swapRouter;

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        FeeInfo memory _feeInfo,
        address _keeper,
        IDataProvider _dataProvider,
        ILendingPool _lendingPool,
        IRewardsController _rewardsController,
        ISwapRouter _swapRouter,
        IUniswapV3Factory _factory,
        IERC20 _native
    ) Vault(_asset, _name, _symbol, _feeInfo, _keeper) {
        lendingPool = _lendingPool;
        dataProvider = _dataProvider;
        rewardsController = _rewardsController;

        (address aTokenAddress,,) = dataProvider.getReserveTokensAddresses(address(asset));
        aToken = IERC20(aTokenAddress);
        native = IERC20(_native);

        swapRouter = _swapRouter;
        factory = _factory;
    }

    function totalAssets() public view override returns (uint256) {
        uint256 assets = asset.balanceOf(address(this));
        (uint256 depositedAssets,,,,,,,,) = dataProvider.getUserReserveData(address(asset), address(this));
        return assets + depositedAssets;
    }

    function _harvest() internal override returns (uint256) {
        address self = address(this);
        uint256 beforeAssets = asset.balanceOf(self);

        address[] memory aTokens = new address[](1);
        aTokens[0] = address(aToken);

        (address[] memory rewardsList,) = rewardsController.claimAllRewardsToSelf(aTokens);

        uint256 rewardsListLength = rewardsList.length;

        if (rewardsListLength == 0) {
            return 0;
        }

        for (uint256 i = 0; i < rewardsListLength; i++) {
            // This function will swap the reward token for the asset token.
            // However, we haven't yet decided which DEX to use.
            // _processReward(rewardsList[i]);
        }

        uint256 afterAssets = asset.balanceOf(self);
        uint256 harvestAssets = afterAssets - beforeAssets;
        return harvestAssets;
    }

    function _deposit(address, uint256) internal override {
        uint256 currentAssets = asset.balanceOf(address(this));
        if (currentAssets > 0) {
            asset.safeIncreaseAllowance(address(lendingPool), currentAssets);
            lendingPool.deposit(address(asset), currentAssets, address(this), 0);
        }
    }

    function _withdraw(address, uint256 assets) internal override {
        uint256 currentAssets = asset.balanceOf(address(this));
        if (assets > currentAssets) {
            uint256 shortAssets = assets - currentAssets;
            lendingPool.withdraw(address(asset), shortAssets, address(this));
        }
    }
}
