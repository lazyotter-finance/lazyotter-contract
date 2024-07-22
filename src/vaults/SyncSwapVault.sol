// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Vault} from "./Vault.sol";

/**
 * @title SyncSwapVault
 * @dev A vault contract for managing deposits and withdrawals, inheriting from the Vault contract.
 */
contract SyncSwapVault is Vault {
    /**
     * @dev Constructor for the SyncSwapVault contract.
     * @param _asset The underlying asset of the vault.
     * @param _name The name of the ERC20 token.
     * @param _symbol The symbol of the ERC20 token.
     * @param _feeInfo The initial fee information.
     * @param _keeper The address of the keeper.
     */
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        FeeInfo memory _feeInfo,
        address _keeper
    ) Vault(_asset, _name, _symbol, _feeInfo, _keeper) {}
}
