// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// It's ok to not use ERC20Upgradeable here
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IDataProvider} from "../../interfaces/aave/IDataProvider.sol";
import {ILendingPool} from "../../interfaces/aave/ILendingPool.sol";

import {Vault} from "./Vault.sol";

import "forge-std/console.sol";

contract AaveVault is Vault {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:aaveVaultStorage
    struct AaveVaultStorage {
        IDataProvider dataProvider;
        ILendingPool lendingPool;
    }

    // keccak256(abi.encode(uint256(keccak256("aaveVaultStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AaveVaultStorageLocation =
        0xbb608e3d0c9e28aeffd46207d323ce6abb54190320b3f8cc0f426d1824ea5100;

    function _getAaveVaultStorage() private pure returns (AaveVaultStorage storage $) {
        assembly {
            $.slot := AaveVaultStorageLocation
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
        IDataProvider dataProvider_,
        ILendingPool lendingPool_
    ) public initializer {
        super.initialize(asset_, name_, symbol_, keeper_);

        AaveVaultStorage storage $ = _getAaveVaultStorage();
        $.dataProvider = dataProvider_;
        $.lendingPool = lendingPool_;
    }

    function totalAssets() public view override returns (uint256) {
        AaveVaultStorage storage $ = _getAaveVaultStorage();
        IERC20 asset = IERC20(asset());

        uint256 assets = asset.balanceOf(address(this));
        (uint256 depositedAssets, , , , , , , , ) = $.dataProvider.getUserReserveData(address(asset), address(this));
        return assets + depositedAssets;
    }

    function _deposit_(address, uint256) internal override {
        AaveVaultStorage storage $ = _getAaveVaultStorage();
        IERC20 asset = IERC20(asset());
        uint256 currentAssets = asset.balanceOf(address(this));

        if (currentAssets > 0) {
            asset.safeIncreaseAllowance(address($.lendingPool), currentAssets);
            $.lendingPool.deposit(address(asset), currentAssets, address(this), 0);
        }
    }

    function _withdraw_(address, uint256 assets) internal override {
        AaveVaultStorage storage $ = _getAaveVaultStorage();
        IERC20 asset = IERC20(asset());
        uint256 currentAssets = asset.balanceOf(address(this));

        if (assets > currentAssets) {
            uint256 shortAssets = assets - currentAssets;
            $.lendingPool.withdraw(address(asset), shortAssets, address(this));
        }
    }
}
