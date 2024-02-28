// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

library UniswapHelper {
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
