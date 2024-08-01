// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface IToken {
    function underlyingBalanceOf(address account) external view returns (uint256);
}
