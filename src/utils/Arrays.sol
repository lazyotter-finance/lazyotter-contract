// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

library Arrays {
    function sum(uint256[] memory array) internal pure returns (uint256) {
        uint256 length = array.length;
        uint256 s = 0;
        for (uint256 i = 0; i < length; ++i) {
            s += array[i];
        }
        return s;
    }
}
