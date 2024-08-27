// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface ICore {
    function supply(address lToken, uint256 uAmount) external payable returns (uint256);

    function redeemUnderlying(address lToken, uint256 uAmount) external returns (uint256);
}
