// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// It's ok to not use ERC20Upgradeable here
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC4626Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";

import {IComptroller} from "../../interfaces/rhoMarkets/IComptroller.sol";
import {IRErc20Delegator} from "../../interfaces/rhoMarkets/IRErc20Delegator.sol";
import {IInterestRateModel} from "../../interfaces/rhoMarkets/IInterestRateModel.sol";

import {Vault} from "./Vault.sol";

import "forge-std/console.sol";

/// @title RhoMarketsVault
/// @notice A vault contract for interacting with Rho Markets
/// @dev This contract extends the Vault contract and interacts with Rho Markets' Comptroller and RErc20 contracts
contract RhoMarketsVault is Vault {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:rhoMarketsVaultStorage
    struct RhoMarketsVaultStorage {
        /// @notice The Comptroller contract of Rho Markets
        IComptroller comptroller;
        /// @notice The RErc20Delegator contract representing the Rho Markets token
        IRErc20Delegator RErc20;
        /// @notice The Interest Rate Model contract used by Rho Markets
        IInterestRateModel interestRateModel;
    }

    // keccak256(abi.encode(uint256(keccak256("rhoMarketsVaultStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant RhoMarketsVaultStorageLocation =
        0x65cb8b90c766a2bfb1810ced6242a6125afe3c11f95d22f36e5aae6418306000;

    function _getRhoMarketsVaultStorage() private pure returns (RhoMarketsVaultStorage storage $) {
        assembly {
            $.slot := RhoMarketsVaultStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address keeper_,
        IRErc20Delegator RErc20_
    ) public initializer {
        super.initialize(asset_, name_, symbol_, keeper_);

        RhoMarketsVaultStorage storage $ = _getRhoMarketsVaultStorage();
        $.RErc20 = RErc20_;
        $.comptroller = IComptroller(RErc20_.comptroller());
        $.interestRateModel = IInterestRateModel(RErc20_.interestRateModel());
    }

    /// @notice Calculates the maximum amount that can be deposited
    /// The address of the depositor (unused in this implementation)
    /// @return The maximum amount that can be deposited
    function maxDeposit(address) public view override returns (uint256) {
        if (paused()) {
            return 0;
        }

        RhoMarketsVaultStorage storage $ = _getRhoMarketsVaultStorage();
        IComptroller comptroller = $.comptroller;
        IRErc20Delegator RErc20 = $.RErc20;
        IInterestRateModel interestRateModel = $.interestRateModel;

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

    /**
     * @notice Returns the maximum amount of shares that can be minted.
     * @param receiver The address of the receiver.
     * @return uint256 Maximum mint amount.
     */
    function maxMint(address receiver) public view override returns (uint256) {
        if (paused()) {
            return 0;
        }

        uint256 _maxDeposit = maxDeposit(receiver);
        if (_maxDeposit == type(uint256).max) {
            return type(uint256).max;
        }
        return _convertToShares(_maxDeposit, Math.Rounding.Floor);
    }

    /// @notice Calculates the maximum amount that can be withdrawn
    /// @param owner The address of the token owner
    /// @return The maximum amount that can be withdrawn
    function maxWithdraw(address owner) public view override returns (uint256) {
        RhoMarketsVaultStorage storage $ = _getRhoMarketsVaultStorage();
        IERC20 asset = IERC20(asset());

        return Math.min(convertToAssets(balanceOf(owner)), $.RErc20.getCash() + asset.balanceOf(address(this)));
    }

    /**
     * @notice Returns the maximum amount of shares that can be redeemed.
     * @param owner The address of the owner.
     * @return uint256 Maximum redeem amount.
     */
    function maxRedeem(address owner) public view override returns (uint256) {
        return _convertToShares(maxWithdraw(owner), Math.Rounding.Floor);
    }

    /// @notice Calculates the total assets managed by the vault
    /// @return The total amount of assets
    function totalAssets() public view override returns (uint256) {
        RhoMarketsVaultStorage storage $ = _getRhoMarketsVaultStorage();
        IRErc20Delegator RErc20 = $.RErc20;
        IERC20 asset = IERC20(asset());

        uint256 assets = asset.balanceOf(address(this));
        uint256 RErc20s = RErc20.balanceOf(address(this));

        uint256 rate = RErc20.exchangeRateStored();
        uint256 depositedAssets = (RErc20s * rate) / 1e18;

        return assets + depositedAssets;
    }

    /// @notice Handles the deposit operation
    /// _ The address of the depositor (unused in this implementation)
    /// _ The amount of assets to deposit (unused in this implementation)
    function _deposit_(address, uint256) internal override returns (uint256) {
        RhoMarketsVaultStorage storage $ = _getRhoMarketsVaultStorage();
        IRErc20Delegator RErc20 = $.RErc20;
        IERC20 asset = IERC20(asset());

        uint256 currentAssets = asset.balanceOf(address(this));
        if (currentAssets > 0) {
            asset.safeIncreaseAllowance(address(RErc20), currentAssets);
            uint256 err = RErc20.mint(currentAssets);
            require(err == 0, "RErc20.mint failed");
        }
    }

    /// @notice Handles the withdrawal operation
    /// _ The address of the withdrawer (unused in this implementation)
    /// @param assets The amount of assets to withdraw
    function _withdraw_(address, uint256 assets) internal override returns (uint256) {
        RhoMarketsVaultStorage storage $ = _getRhoMarketsVaultStorage();
        IRErc20Delegator RErc20 = $.RErc20;
        IERC20 asset = IERC20(asset());

        uint256 realWithdrawAssets = assets;
        uint256 currentAssets = asset.balanceOf(address(this));
        if (assets > currentAssets) {
            uint256 shortAssets = assets - currentAssets;
            uint256 balanceBefore = asset.balanceOf(address(this));

            uint256 err = RErc20.redeemUnderlying(shortAssets);
            require(err == 0, "RErc20.redeemUnderlying failed");

            uint256 balanceAfter = asset.balanceOf(address(this));
            realWithdrawAssets = balanceAfter - balanceBefore;
        }

        return realWithdrawAssets;
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        uint256 realWithdrawAssets = _withdraw_(owner, assets);

        ERC4626Upgradeable._withdraw(caller, receiver, owner, realWithdrawAssets, shares);
    }
}
