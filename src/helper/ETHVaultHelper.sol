// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IWETH} from "../interfaces/lazyotter/IWETH.sol";
import {IVault} from "../interfaces/lazyotter/IVault.sol";

/**
 * @title ETHVaultHelper
 * @dev Helper contract for interacting with WETH and vaults.
 */
contract ETHVaultHelper {
    using Address for address payable;

    /// @notice The WETH contract.
    IWETH public immutable WETH;

    /**
     * @dev Constructor for the ETHVaultHelper contract.
     * @param weth The address of the WETH contract.
     */
    constructor(address weth) {
        WETH = IWETH(weth);
    }

    /**
     * @notice Deposits ETH into a vault and mints corresponding shares for the receiver.
     * @param vault The address of the vault.
     * @param receiver The address to receive the shares.
     */
    function depositETH(address vault, address receiver) external payable {
        WETH.deposit{value: msg.value}();
        WETH.approve(vault, msg.value);
        IVault(vault).deposit(msg.value, receiver);
    }

    /**
     * @notice Mints shares in the vault for the receiver using ETH.
     * @param vault The address of the vault.
     * @param shares The amount of shares to mint.
     * @param receiver The address to receive the shares.
     */
    function mintETH(address vault, uint256 shares, address receiver) external payable {
        WETH.deposit{value: msg.value}();
        WETH.approve(vault, msg.value);
        IVault(vault).mint(shares, receiver);

        uint256 balance = WETH.balanceOf(address(this));
        if (balance > 0) {
            WETH.withdraw(balance);
            payable(msg.sender).sendValue(balance);
        }
    }

    /**
     * @notice Withdraws assets from the vault and sends ETH to the sender.
     * @param vault The address of the vault.
     * @param assets The amount of assets to withdraw.
     */
    function withdrawETH(address vault, uint256 assets) external {
        address payable owner = payable(msg.sender);

        IVault(vault).withdraw(assets, address(this), owner);
        WETH.withdraw(assets);
        owner.sendValue(assets);
    }

    /**
     * @notice Redeems shares from the vault and sends ETH to the sender.
     * @param vault The address of the vault.
     * @param shares The amount of shares to redeem.
     */
    function redeemETH(address vault, uint256 shares) external {
        address payable owner = payable(msg.sender);

        uint256 assets = IVault(vault).redeem(shares, address(this), owner);
        WETH.withdraw(assets);
        owner.sendValue(assets);
    }

    /**
     * @dev Fallback function to receive ETH. Only allows deposits from the WETH contract.
     */
    receive() external payable {
        require(msg.sender == address(WETH), "Receive not allowed");
    }

    /**
     * @dev Fallback function to revert unexpected transactions.
     */
    fallback() external payable {
        revert("Fallback not allowed");
    }
}
