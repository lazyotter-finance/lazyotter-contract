// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface ICrocQuery {
    struct CurveState {
        uint128 priceRoot_;
        uint128 ambientSeeds_;
        uint128 concLiq_;
        uint64 seedDeflator_;
        uint64 concGrowth_;
    }

    struct Pool {
        uint8 schema_;
        uint16 feeRate_;
        uint8 protocolTake_;
        uint16 tickSize_;
        uint8 jitThresh_;
        uint8 knockoutBits_;
        uint8 oracleFlags_;
    }

    function queryPrice(address base, address quote, uint256 poolIdx) external view returns (uint128);

    function queryLiquidity(address base, address quote, uint256 poolIdx) external view returns (uint128);

    function queryCurveTick(address base, address quote, uint256 poolIdx) external view returns (int24);

    function queryCurve(address base, address quote, uint256 poolIdx) external view returns (CurveState memory);

    function queryPoolParams(address base, address quote, uint256 poolIdx) external view returns (Pool memory);
}
