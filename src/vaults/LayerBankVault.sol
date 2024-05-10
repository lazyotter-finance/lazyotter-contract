// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {ICore} from "../interfaces/layerbank/ICore.sol";
import {IToken} from "../interfaces/layerbank/IToken.sol";

import {Vault} from "./Vault.sol";

contract LayerBankVault is Vault {
    using SafeERC20 for IERC20;

    // Tokens used
    IERC20 public native;
    IToken public iToken;

    // Third party contracts
    ICore public core;

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        FeeInfo memory _feeInfo,
        address _keeper,
        ICore _core,
        IToken _iToken,
        IERC20 _native
    ) Vault(_asset, _name, _symbol, _feeInfo, _keeper) {
        core = _core;
        iToken = _iToken;

        native = IERC20(_native);
    }

    function totalAssets() public view override returns (uint256) {
        uint256 assets = asset.balanceOf(address(this));
        uint256 depositedAssets = iToken.underlyingBalanceOf(address(this));
        return assets + depositedAssets;
    }

    function _deposit(address, uint256) internal override {
        uint256 currentAssets = asset.balanceOf(address(this));
        if (currentAssets > 0) {
            asset.safeIncreaseAllowance(address(iToken), currentAssets);
            core.supply(address(iToken), currentAssets);
        }
    }

    function _withdraw(address, uint256 assets) internal override {
        uint256 currentAssets = asset.balanceOf(address(this));
        if (assets > currentAssets) {
            uint256 shortAssets = assets - currentAssets;
            core.redeemUnderlying(address(iToken), shortAssets);
        }
    }
}
