// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IComptroller} from "../interfaces/rhoMarkets/IComptroller.sol";
import {IRErc20Delegator} from "../interfaces/rhoMarkets/IRErc20Delegator.sol";
import {IInterestRateModel} from "../interfaces/rhoMarkets/IInterestRateModel.sol";

import {Vault} from "./Vault.sol";

/// @title RhoMarketsVault
/// @notice A vault contract for interacting with Rho Markets
/// @dev This contract extends the Vault contract and interacts with Rho Markets' Comptroller and RErc20 contracts
contract RhoMarketsVault is Vault {
    using SafeERC20 for IERC20;

    /// @notice The Comptroller contract of Rho Markets
    IComptroller public comptroller;

    /// @notice The RErc20Delegator contract representing the Rho Markets token
    IRErc20Delegator public RErc20;

    /// @notice The Interest Rate Model contract used by Rho Markets
    IInterestRateModel public interestRateModel;

    /// @notice Initializes the RhoMarketsVault
    /// @param _asset The ERC20 token that the vault will manage
    /// @param _name The name of the vault token
    /// @param _symbol The symbol of the vault token
    /// @param _feeInfo The fee structure for the vault
    /// @param _keeper The address of the keeper
    /// @param _RErc20 The address of the RErc20Delegator contract
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        FeeInfo memory _feeInfo,
        address _keeper,
        IRErc20Delegator _RErc20
    ) Vault(_asset, _name, _symbol, _feeInfo, _keeper) {
        RErc20 = _RErc20;
        comptroller = IComptroller(_RErc20.comptroller());
        interestRateModel = IInterestRateModel(_RErc20.interestRateModel());
    }

    /// @notice Calculates the maximum amount that can be deposited
    /// The address of the depositor (unused in this implementation)
    /// @return The maximum amount that can be deposited
    function maxDeposit(address) public view override returns (uint256) {
        // Supply cap of 0 corresponds to unlimited supplying
        uint256 supplyCap = comptroller.supplyCaps(address(RErc20));
        if (supplyCap == 0) {
            return type(uint256).max;
        }

        uint256 totalCash = RErc20.getCash();
        uint256 totalBorrows = RErc20.totalBorrows();
        uint256 totalReserves = RErc20.totalReserves();

        uint256 borrowRate = interestRateModel.getBorrowRate(totalCash, totalBorrows, totalReserves);

        uint256 simpleInterestFactor = borrowRate * (block.number - RErc20.accrualBlockNumber());
        uint256 interestAccumulated = (simpleInterestFactor * totalBorrows) / 1e18;

        totalBorrows = interestAccumulated + totalBorrows;
        totalReserves = (interestAccumulated * RErc20.reserveFactorMantissa()) / 1e18 + totalReserves;

        uint256 totalSupplies = totalCash + totalBorrows - totalReserves;

        if (supplyCap > totalSupplies) {
            return supplyCap - totalSupplies - 1;
        }

        return 0;
    }

    /// @notice Calculates the maximum amount that can be withdrawn
    /// @param owner The address of the token owner
    /// @return The maximum amount that can be withdrawn
    function maxWithdraw(address owner) public view override returns (uint256) {
        return Math.min(convertToAssets(balanceOf(owner)), RErc20.getCash());
    }

    /// @notice Calculates the total assets managed by the vault
    /// @return The total amount of assets
    function totalAssets() public view override returns (uint256) {
        uint256 assets = asset.balanceOf(address(this));
        uint256 RErc20s = RErc20.balanceOf(address(this));

        uint256 rate = RErc20.exchangeRateStored();
        uint256 depositedAssets = (RErc20s * rate) / 1e18;

        return assets + depositedAssets;
    }

    /// @notice Performs the harvest operation
    /// @return The amount harvested (always 0 in this implementation)
    function _harvest() internal pure override returns (uint256) {
        return 0;
    }

    /// @notice Handles the deposit operation
    /// _ The address of the depositor (unused in this implementation)
    /// _ The amount of assets to deposit (unused in this implementation)
    function _deposit(address, uint256) internal override {
        uint256 currentAssets = asset.balanceOf(address(this));
        if (currentAssets > 0) {
            asset.safeIncreaseAllowance(address(RErc20), currentAssets);
            RErc20.mint(currentAssets);
        }
    }

    /// @notice Handles the withdrawal operation
    /// _ The address of the withdrawer (unused in this implementation)
    /// @param assets The amount of assets to withdraw
    function _withdraw(address, uint256 assets) internal override {
        uint256 currentAssets = asset.balanceOf(address(this));
        if (assets > currentAssets) {
            uint256 shortAssets = assets - currentAssets;
            RErc20.redeemUnderlying(shortAssets);
        }
    }
}
