// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface ICrocImpact {
    function calcImpact(
        address base,
        address quote,
        uint256 poolIdx,
        bool isBuy,
        bool inBaseQty,
        uint128 qty,
        uint16 tip,
        uint128 limitPrice
    ) external view returns (int128 baseFlow, int128 quoteFlow, uint128 finalPrice);
}
