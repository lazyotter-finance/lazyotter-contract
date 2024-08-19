// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IWETH} from "../interfaces/lazyotter/IWETH.sol";
import {ICore} from "../interfaces/layerbank/ICore.sol";
import {IToken} from "../interfaces/layerbank/IToken.sol";

import {Vault} from "./Vault.sol";

/**
 * @title LayerBankVault
 * @dev A vault contract that integrates with LayerBank for deposit and withdrawal of assets.
 */
contract LayerBankVault is Vault {
    using SafeERC20 for IERC20;

    /// @notice The native token used for rewards.
    IERC20 public native;
    /// @notice The LayerBank iToken representation of the deposited asset.
    IToken public iToken;
    /// @notice The WETH contract.
    IWETH public immutable WETH;

    /// @notice LayerBank core contract.
    ICore public core;

    /**
     * @dev Constructor for the LayerBankVault contract.
     * @param _asset The underlying asset of the vault.
     * @param _name The name of the ERC20 token.
     * @param _symbol The symbol of the ERC20 token.
     * @param _feeInfo The initial fee information.
     * @param _keeper The address of the keeper.
     * @param _core The LayerBank core contract.
     * @param _iToken The LayerBank iToken contract.
     * @param _native The native token used for rewards.
     */
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        FeeInfo memory _feeInfo,
        address _keeper,
        ICore _core,
        IToken _iToken,
        address weth,
        IERC20 _native
    ) Vault(_asset, _name, _symbol, _feeInfo, _keeper) {
        core = _core;
        iToken = _iToken;
        native = _native;
        WETH = IWETH(weth);
    }

    /**
     * @notice Returns the total assets held by the vault, including those deposited in LayerBank.
     * @return uint256 Total assets.
     */
    function totalAssets() public view override returns (uint256) {
        uint256 assets = asset.balanceOf(address(this));
        uint256 depositedAssets = iToken.underlyingBalanceOf(address(this));
        return assets + depositedAssets;
    }

    /**
     * @dev Internal function to handle asset deposits into LayerBank.
     */
    function _deposit(address, uint256) internal override {
        uint256 currentAssets = asset.balanceOf(address(this));
        if (address(asset) == address(WETH)) {
            WETH.withdraw(currentAssets);
        }

        if (currentAssets > 0) {
            if (address(asset) == address(WETH)) {
                core.supply{value: currentAssets}(address(iToken), currentAssets);
            } else {
                asset.safeIncreaseAllowance(address(iToken), currentAssets);
                core.supply(address(iToken), currentAssets);
            }
        }
    }

    /**
     * @dev Internal function to handle asset withdrawals from LayerBank.
     * @param assets The amount of assets to withdraw.
     */
    function _withdraw(address, uint256 assets) internal override {
        uint256 currentAssets = asset.balanceOf(address(this));
        if (assets > currentAssets) {
            uint256 shortAssets = assets - currentAssets;
            core.redeemUnderlying(address(iToken), shortAssets);
            if (address(asset) == address(WETH)) {
                WETH.deposit{value: shortAssets}();
            }
        }
    }

    receive() external payable {}
}
