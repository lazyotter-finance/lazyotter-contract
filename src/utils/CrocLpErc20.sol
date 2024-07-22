// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICrocSwapDex} from "../interfaces/ambient/ICrocSwapDex.sol";
import {ICrocLpConduit} from "../interfaces/ambient/ICrocLpConduit.sol";

import "forge-std/console.sol";

contract CrocLpErc20 is ERC20, ReentrancyGuard, ICrocLpConduit {
    using SafeERC20 for IERC20;

    // if the pair is ETH/USDC, baseToken is ETH, quoteToken is USDC
    ICrocSwapDex public immutable crocSwapDex;
    address public immutable baseToken;
    address public immutable quoteToken;
    bytes32 public immutable poolHash;
    uint256 public immutable poolType;

    constructor(
        ICrocSwapDex _crocSwapDex,
        address _base,
        address _quote,
        uint256 _poolIdx
    ) ERC20("Croc Ambient LP ERC20 Token", "LP-CrocAmb") {
        // CrocSwap protocol uses 0x0 for native ETH, so it's possible that base
        // token could be 0x0, which means the pair is against native ETH. quote
        // will never be 0x0 because native ETH will always be the base side of
        // the pair.
        require(_quote != address(0) && _base != _quote && _quote > _base, "Invalid Token Pair");

        crocSwapDex = _crocSwapDex;
        baseToken = _base;
        quoteToken = _quote;
        poolType = _poolIdx;
        poolHash = keccak256(abi.encode(_base, _quote, _poolIdx));
    }

    modifier onlyCrocSwapDex() {
        require(msg.sender == address(crocSwapDex), "Only CrocSwapDex can call this function");
        _;
    }

    function depositCrocLiq(
        address sender,
        bytes32 pool,
        int24 lowerTick,
        int24 upperTick,
        uint128 seeds,
        uint72
    ) public override nonReentrant onlyCrocSwapDex returns (bool) {
        require(pool == poolHash, "Wrong pool");
        require(lowerTick == 0 && upperTick == 0, "Non-Ambient LP Deposit");
        _mint(sender, seeds);
        return true;
    }

    function withdrawCrocLiq(
        address sender,
        bytes32 pool,
        int24 lowerTick,
        int24 upperTick,
        uint128 seeds,
        uint72
    ) public override nonReentrant onlyCrocSwapDex returns (bool) {
        require(pool == poolHash, "Wrong pool");
        require(lowerTick == 0 && upperTick == 0, "Non-Ambient LP Deposit");
        _burn(sender, seeds);
        return true;
    }
}
