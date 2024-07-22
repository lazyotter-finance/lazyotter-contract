// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

/**
 * @title UniswapHelper
 * @dev Library for interacting with Uniswap V3 pools to find the best fee tier.
 */
library UniswapHelper {
    /**
     * @notice Gets the best fee tier for a given token pair from Uniswap V3 pools.
     * @param factory The Uniswap V3 factory contract.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @return uint24 The best fee tier for the given token pair.
     */
    function getBestFee(IUniswapV3Factory factory, address tokenA, address tokenB) internal view returns (uint24) {
        uint24[] memory feeTiers = new uint24[](3);
        feeTiers[0] = 500; // 0.05%
        feeTiers[1] = 3000; // 0.3%
        feeTiers[2] = 10000; // 1%
        uint128 maxLiquidity = 0;
        uint24 bestFee = 0;

        uint256 length = feeTiers.length;
        for (uint256 i = 0; i < length; i++) {
            IUniswapV3Pool pool = IUniswapV3Pool(factory.getPool(tokenA, tokenB, feeTiers[i]));
            if (address(pool) == address(0)) {
                continue;
            }
            uint128 liquidity = pool.liquidity();

            if (liquidity > maxLiquidity) {
                maxLiquidity = liquidity;
                bestFee = feeTiers[i];
            }
        }

        return bestFee;
    }
}
