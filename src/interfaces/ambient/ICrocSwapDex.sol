// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface ICrocSwapDex {
    function userCmd(uint16 callpath, bytes calldata cmd) external payable returns (bytes memory);
}
