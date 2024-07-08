// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Zap
 * @dev Library for calculating delta values in a liquidity pool with fee considerations.
 */
library Zap {
    /**
     * @notice Calculate the amount of token X a user needs to swap to add liquidity
     * @param x The amount of token X in pool.
     * @param y The amount of token Y in pool.
     * @param n The amount of token X user deposited.
     * @param m The amount of token Y user deposited.
     * @param fee The swap fee with decimals.
     * @param maxFee The maximum swap fee with decimals.
     * @return uint256 The calculated delta value for X.
     */
    function getDeltaX(uint256 x, uint256 y, uint256 n, uint256 m, uint256 fee, uint256 maxFee)
        internal
        pure
        returns (uint256)
    {
        uint256 maxFeeMinusFee = maxFee - fee;
        uint256 mPlusY = m + y;
        uint256 nPlusX = n + x;

        uint256 leftFraction = _leftFraction(x, fee, maxFeeMinusFee);

        uint256 rightNumeratorLeftPart = _rightNumeratorLeftPart(x, fee, mPlusY);
        uint256 rightNumeratorRightPart = _rightNumeratorRightPart(x, y, maxFee, nPlusX, maxFeeMinusFee, mPlusY);
        uint256 rightNumerator = _rightNumerator(rightNumeratorLeftPart, rightNumeratorRightPart);
        uint256 rightDenominator = _rightDenominator(mPlusY, maxFeeMinusFee);
        uint256 rightFraction = _rightFraction(rightNumerator, rightDenominator);

        uint256 deltaX = rightFraction - leftFraction;

        return deltaX;
    }

    /**
     * @dev Calculates the left fraction used in the delta calculation.
     * @param _x The initial amount of token X.
     * @param _fee The transaction fee.
     * @param _maxFeeMinusFee The difference between max fee and the transaction fee.
     * @return uint256 The calculated left fraction.
     */
    function _leftFraction(uint256 _x, uint256 _fee, uint256 _maxFeeMinusFee) private pure returns (uint256) {
        return Math.mulDiv(2 * _x * _maxFeeMinusFee + _x * _fee, 1, 2 * _maxFeeMinusFee, Math.Rounding.Trunc);
    }

    /**
     * @dev Calculates the right fraction used in the delta calculation.
     * @param _numerator The numerator of the right fraction.
     * @param _denominator The denominator of the right fraction.
     * @return uint256 The calculated right fraction.
     */
    function _rightFraction(uint256 _numerator, uint256 _denominator) private pure returns (uint256) {
        return Math.mulDiv(_numerator, 1, _denominator, Math.Rounding.Trunc);
    }

    /**
     * @dev Calculates the left part of the numerator used in the right fraction.
     * @param _x The initial amount of token X.
     * @param _fee The transaction fee.
     * @param _mPlusY The sum of m and y.
     * @return uint256 The calculated left part of the numerator.
     */
    function _rightNumeratorLeftPart(uint256 _x, uint256 _fee, uint256 _mPlusY) private pure returns (uint256) {
        return (_x * _x * _fee * _fee * _mPlusY * _mPlusY);
    }

    /**
     * @dev Calculates the right part of the numerator used in the right fraction.
     * @param _x The initial amount of token X.
     * @param _y The initial amount of token Y.
     * @param _maxFee The maximum allowable fee.
     * @param _nPlusX The sum of n and x.
     * @param _maxFeeMinusFee The difference between max fee and the transaction fee.
     * @param _mPlusY The sum of m and y.
     * @return uint256 The calculated right part of the numerator.
     */
    function _rightNumeratorRightPart(
        uint256 _x,
        uint256 _y,
        uint256 _maxFee,
        uint256 _nPlusX,
        uint256 _maxFeeMinusFee,
        uint256 _mPlusY
    ) private pure returns (uint256) {
        return 4 * _x * _y * _maxFee * _nPlusX * _maxFeeMinusFee * _mPlusY;
    }

    /**
     * @dev Combines the left and right parts of the numerator used in the right fraction.
     * @param _leftPart The left part of the numerator.
     * @param _rightPart The right part of the numerator.
     * @return uint256 The combined numerator.
     */
    function _rightNumerator(uint256 _leftPart, uint256 _rightPart) private pure returns (uint256) {
        return Math.sqrt(_leftPart + _rightPart, Math.Rounding.Trunc);
    }

    /**
     * @dev Calculates the denominator used in the right fraction.
     * @param _mPlusY The sum of m and y.
     * @param _maxFeeMinusFee The difference between max fee and the transaction fee.
     * @return uint256 The calculated denominator.
     */
    function _rightDenominator(uint256 _mPlusY, uint256 _maxFeeMinusFee) private pure returns (uint256) {
        return 2 * _mPlusY * _maxFeeMinusFee;
    }
}
