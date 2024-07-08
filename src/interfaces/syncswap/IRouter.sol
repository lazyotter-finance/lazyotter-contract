// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IPool} from "./IPool.sol";

interface IRouter {
    struct TokenInput {
        address token;
        uint256 amount;
    }

    struct SwapStep {
        address pool; // The pool of the step.
        bytes data; // The data to execute swap with the pool.
        address callback;
        bytes callbackData;
    }

    struct SwapPath {
        SwapStep[] steps; // Steps of the path.
        address tokenIn; // The input token of the path.
        uint256 amountIn; // The input token amount of the path.
    }

    struct SplitPermitParams {
        address token;
        uint256 approveAmount;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct ArrayPermitParams {
        uint256 approveAmount;
        uint256 deadline;
        bytes signature;
    }

    // Returns the vault address.
    function vault() external view returns (address);

    // Returns the wETH address.
    function wETH() external view returns (address);

    // Adds some liquidity (supports unbalanced mint).
    // Alternatively, use `addLiquidity2` with the same params to register the position,
    // to make sure it can be indexed by the interface.
    function addLiquidity(
        address pool,
        TokenInput[] calldata inputs,
        bytes calldata data,
        uint256 minLiquidity,
        address callback,
        bytes calldata callbackData
    ) external payable returns (uint256 liquidity);

    function addLiquidity2(
        address pool,
        TokenInput[] calldata inputs,
        bytes calldata data,
        uint256 minLiquidity,
        address callback,
        bytes calldata callbackData
    ) external payable returns (uint256 liquidity);

    // Adds some liquidity with permit (supports unbalanced mint).
    // Alternatively, use `addLiquidityWithPermit` with the same params to register the position,
    // to make sure it can be indexed by the interface.
    function addLiquidityWithPermit(
        address pool,
        TokenInput[] calldata inputs,
        bytes calldata data,
        uint256 minLiquidity,
        address callback,
        bytes calldata callbackData,
        SplitPermitParams[] memory permits
    ) external payable returns (uint256 liquidity);

    // Burns some liquidity (balanced).
    function burnLiquidity(
        address pool,
        uint256 liquidity,
        bytes calldata data,
        uint256[] calldata minAmounts,
        address callback,
        bytes calldata callbackData
    ) external returns (IPool.TokenAmount[] memory amounts);

    // Burns some liquidity with permit (balanced).
    function burnLiquidityWithPermit(
        address pool,
        uint256 liquidity,
        bytes calldata data,
        uint256[] calldata minAmounts,
        address callback,
        bytes calldata callbackData,
        ArrayPermitParams memory permit
    ) external returns (IPool.TokenAmount[] memory amounts);

    // Burns some liquidity (single).
    function burnLiquiditySingle(
        address pool,
        uint256 liquidity,
        bytes memory data,
        uint256 minAmount,
        address callback,
        bytes memory callbackData
    ) external returns (IPool.TokenAmount memory amounts);

    // Burns some liquidity with permit (single).
    function burnLiquiditySingleWithPermit(
        address pool,
        uint256 liquidity,
        bytes memory data,
        uint256 minAmount,
        address callback,
        bytes memory callbackData,
        ArrayPermitParams calldata permit
    ) external returns (IPool.TokenAmount memory amounts);

    // Performs a swap.
    function swap(SwapPath[] memory paths, uint256 amountOutMin, uint256 deadline)
        external
        payable
        returns (IPool.TokenAmount memory amounts);

    function swapWithPermit(
        SwapPath[] memory paths,
        uint256 amountOutMin,
        uint256 deadline,
        SplitPermitParams calldata permit
    ) external payable returns (IPool.TokenAmount memory amounts);

    /// @notice Wrapper function to allow pool deployment to be batched.
    function createPool(address factory, bytes calldata data) external payable returns (address);
}
