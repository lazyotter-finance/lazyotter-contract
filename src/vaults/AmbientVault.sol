// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICrocSwapDex} from "../interfaces/ambient/ICrocSwapDex.sol";
import {ICrocLpConduit} from "../interfaces/ambient/ICrocLpConduit.sol";

import {Vault} from "./Vault.sol";

import "forge-std/console.sol";

contract AmbientVault is Vault {
    using SafeERC20 for IERC20;

    // if the pair is ETH/USDC, baseToken is ETH, quoteToken is USDC
    address public immutable baseToken;
    address public immutable quoteToken;

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        FeeInfo memory _feeInfo,
        address _keeper
    ) Vault(_asset, _name, _symbol, _feeInfo, _keeper) {
        baseToken = ICrocLpConduit(address(_asset)).baseToken();
        quoteToken = ICrocLpConduit(address(_asset)).quoteToken();
    }
}
