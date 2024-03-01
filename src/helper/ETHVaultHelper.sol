// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IWETH} from "../interfaces/lazyotter/IWETH.sol";
import {IVault} from "../interfaces/lazyotter/IVault.sol";

contract ETHVaultHelper {
    using Address for address payable;

    IWETH public immutable WETH;

    constructor(address weth) {
        WETH = IWETH(weth);
    }

    function depositETH(address vault, address receiver) external payable {
        WETH.deposit{value: msg.value}();
        WETH.approve(vault, msg.value);
        IVault(vault).deposit(msg.value, receiver);
    }

    function mintETH(address vault, uint256 shares, address receiver) external payable {
        uint256 assets = IVault(vault).previewMint(shares);
        require(assets == msg.value, "wrong eth amount");
        
        WETH.deposit{value: msg.value}();
        WETH.approve(vault, msg.value);
        IVault(vault).mint(shares, receiver);
    }

    function withdrawETH(address vault, uint256 assets) external {
        address payable owner = payable(msg.sender);

        IVault(vault).withdraw(assets, address(this), owner);
        WETH.withdraw(assets);
        owner.sendValue(assets);
    }

    function redeemETH(address vault, uint256 shares) external {
        address payable owner = payable(msg.sender);

        uint256 assets = IVault(vault).redeem(shares, address(this), owner);
        WETH.withdraw(assets);
        owner.sendValue(assets);
    }

    receive() external payable {
        require(msg.sender == address(WETH), "Receive not allowed");
    }

    fallback() external payable {
        revert("Fallback not allowed");
    }
}
