// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Zap} from "../utils/Zap.sol";

import {IRouter} from "../interfaces/syncswap/IRouter.sol";
import {IPool} from "../interfaces/syncswap/IPool.sol";
import {IVault} from "../interfaces/lazyotter/IVault.sol";
import {IWETH} from "../interfaces/lazyotter/IWETH.sol";

/**
 * @title SyncSwapVaultHelper
 * @dev Helper contract for interacting with SyncSwap pools and vaults.
 */
contract SyncSwapVaultHelper {
    struct TokenInput {
        address token;
        uint256 amount;
    }

    using SafeERC20 for IERC20;
    using Address for address;

    /// @notice The address representing native ETH.
    address public constant NATIVE_ETH = address(0);
    /// @notice The maximum fee constant.
    uint256 public constant MAX_FEE = 100_000;
    /// @notice The SyncSwap router contract.
    IRouter public router;

    /**
     * @dev Constructor for the SyncSwapVaultHelper contract.
     * @param _router The SyncSwap router contract address.
     */
    constructor(IRouter _router) {
        router = _router;
    }

    /**
     * @notice Deposits assets into a SyncSwap pool and then into a vault.
     * @param inputs Array of token inputs.
     * @param minLiquidity Minimum liquidity to add.
     * @param deadline Transaction deadline.
     * @param vault The vault address.
     * @param receiver The address to receive the shares.
     * @return uint256 The amount of shares received.
     */
    function deposit(
        TokenInput[] calldata inputs,
        uint256 minLiquidity,
        uint256 deadline,
        address vault,
        address receiver
    ) external payable returns (uint256) {
        address pool = address(IVault(vault).asset());

        IRouter.TokenInput[] memory convertedInputs = _convertToIRouterTokenInput(inputs);
        require(convertedInputs.length < 3, "TOO_MANY_INPUT_TOKENS");

        for (uint256 i = 0; i < convertedInputs.length; i++) {
            _transferFromSender(convertedInputs[i].token, convertedInputs[i].amount);
        }

        convertedInputs = _normalizeIRouterTokenInput(pool, convertedInputs);

        // n * y > m * x
        bool swap0To1 =
            convertedInputs[0].amount * IPool(pool).reserve1() > convertedInputs[1].amount * IPool(pool).reserve0();
        uint24 swapFee = _getSwapFee(pool, swap0To1);

        uint256 deltaX;
        if (swap0To1) {
            deltaX = Zap.getDeltaX(
                IPool(pool).reserve0(),
                IPool(pool).reserve1(),
                convertedInputs[0].amount,
                convertedInputs[1].amount,
                swapFee,
                MAX_FEE
            );
        } else {
            deltaX = Zap.getDeltaX(
                IPool(pool).reserve1(),
                IPool(pool).reserve0(),
                convertedInputs[1].amount,
                convertedInputs[0].amount,
                swapFee,
                MAX_FEE
            );
        }

        // swap if deltaX is not 0
        if (deltaX != 0 && swap0To1) {
            IERC20(convertedInputs[0].token).approve(address(router), deltaX);
            IPool.TokenAmount memory amountOut = _swap(pool, convertedInputs[0].token, deltaX, deadline);

            convertedInputs[0].amount -= deltaX;
            convertedInputs[1].amount += amountOut.amount;
        } else if (deltaX != 0 && !swap0To1) {
            IERC20(convertedInputs[1].token).approve(address(router), deltaX);
            IPool.TokenAmount memory amountOut = _swap(pool, convertedInputs[1].token, deltaX, deadline);

            convertedInputs[0].amount += amountOut.amount;
            convertedInputs[1].amount -= deltaX;
        }

        // add liquidity to SyncSwap pool
        IERC20(convertedInputs[0].token).approve(address(router), convertedInputs[0].amount);
        IERC20(convertedInputs[1].token).approve(address(router), convertedInputs[1].amount);
        uint256 liquidity = router.addLiquidity2(
            pool, convertedInputs, abi.encode(address(this)), minLiquidity, address(0), abi.encode(0)
        );

        // deposit LP token to vault
        IERC20(pool).approve(vault, liquidity);
        uint256 shares = IVault(vault).deposit(liquidity, receiver);

        return shares;
    }

    /**
     * @notice Redeems shares from the vault.
     * @param vault The vault address.
     * @param tokenOut The token to be received after redemption.
     * @param shares The amount of shares to redeem.
     * @param minAmount The minimum amount of tokens to be received.
     * @param receiver The address to receive the tokens.
     * @return uint256 The amount of tokens received.
     */
    function redeem(address vault, address tokenOut, uint256 shares, uint256 minAmount, address receiver)
        external
        returns (uint256)
    {
        uint256 liquidity = IVault(vault).redeem(shares, address(this), msg.sender);

        address pool = address(IVault(vault).asset());
        uint256 amountOut = _removeLiquidity(pool, liquidity, tokenOut, receiver, minAmount);

        return amountOut;
    }

    /**
     * @notice Withdraws assets from the vault.
     * @param vault The vault address.
     * @param tokenOut The token to be received after withdrawal.
     * @param assets The amount of assets to withdraw.
     * @param minAmount The minimum amount of tokens to be received.
     * @param receiver The address to receive the tokens.
     * @return uint256 The amount of tokens received.
     */
    function withdraw(address vault, address tokenOut, uint256 assets, uint256 minAmount, address receiver)
        external
        returns (uint256)
    {
        IVault(vault).withdraw(assets, address(this), msg.sender);

        // remove liquidity from SyncSwap
        address pool = address(IVault(vault).asset());
        uint256 amountOut = _removeLiquidity(pool, assets, tokenOut, receiver, minAmount);

        return amountOut;
    }

    /**
     * @dev Removes liquidity from a SyncSwap pool.
     * @param pool The pool address.
     * @param liquidity The amount of liquidity to remove.
     * @param tokenOut The token to be received after removing liquidity.
     * @param receiver The address to receive the tokens.
     * @param minAmount The minimum amount of tokens to be received.
     * @return uint256 The amount of tokens received.
     */
    function _removeLiquidity(address pool, uint256 liquidity, address tokenOut, address receiver, uint256 minAmount)
        private
        returns (uint256)
    {
        IERC20(pool).approve(address(router), liquidity);
        IPool.TokenAmount memory amountOut = router.burnLiquiditySingle(
            pool, liquidity, abi.encode(tokenOut, receiver, uint8(1)), minAmount, address(0), abi.encode(0)
        );

        return amountOut.amount;
    }

    /**
     * @dev Swaps tokens within a SyncSwap pool.
     * @param pool The pool address.
     * @param tokenIn The token to be swapped.
     * @param amountIn The amount of tokens to swap.
     * @param deadline The transaction deadline.
     * @return IPool.TokenAmount The amount of tokens received after the swap.
     */
    function _swap(address pool, address tokenIn, uint256 amountIn, uint256 deadline)
        private
        returns (IPool.TokenAmount memory)
    {
        IRouter.SwapStep[] memory steps = new IRouter.SwapStep[](1);
        steps[0] = IRouter.SwapStep({
            pool: pool,
            data: abi.encode(tokenIn, address(this), uint8(2)), // withdraw mode 2: wrapped ETH
            callback: address(0),
            callbackData: abi.encode(0)
        });

        IRouter.SwapPath[] memory paths = new IRouter.SwapPath[](1);
        paths[0] = IRouter.SwapPath({steps: steps, tokenIn: tokenIn, amountIn: amountIn});

        IPool.TokenAmount memory amountOut = router.swap(paths, 0, deadline);

        return amountOut;
    }

    /**
     * @dev Transfers tokens from the sender to the contract.
     * @param token The token address.
     * @param amount The amount of tokens to transfer.
     */
    function _transferFromSender(address token, uint256 amount) private {
        if (token == NATIVE_ETH) {
            require(msg.value == amount, "INCORRECT_ETH_AMOUNT");
            IWETH(router.wETH()).deposit{value: amount}();
            IWETH(router.wETH()).approve(address(router), amount);
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            IERC20(token).approve(address(router), amount);
        }
    }

    /**
     * @dev Normalizes token inputs for a SyncSwap pool.
     * @param pool The pool address.
     * @param inputs The token inputs.
     * @return IRouter.TokenInput[] The normalized token inputs.
     */
    function _normalizeIRouterTokenInput(address pool, IRouter.TokenInput[] memory inputs)
        private
        view
        returns (IRouter.TokenInput[] memory)
    {
        IRouter.TokenInput[] memory normalizedInputs = new IRouter.TokenInput[](2);
        uint256 amount0 = 0;
        uint256 amount1 = 0;

        for (uint256 i = 0; i < inputs.length; i++) {
            if (inputs[i].token == NATIVE_ETH) {
                inputs[i].token = router.wETH();
            }

            if (inputs[i].token == IPool(pool).token0()) {
                amount0 = inputs[i].amount;
            } else if (inputs[i].token == IPool(pool).token1()) {
                amount1 = inputs[i].amount;
            } else {
                revert();
            }
        }

        normalizedInputs[0] = IRouter.TokenInput({token: IPool(pool).token0(), amount: amount0});
        normalizedInputs[1] = IRouter.TokenInput({token: IPool(pool).token1(), amount: amount1});

        return normalizedInputs;
    }

    /**
     * @dev Gets the swap fee for a SyncSwap pool.
     * @param pool The pool address.
     * @param swap0To1 Whether the swap is from token0 to token1.
     * @return uint24 The swap fee.
     */
    function _getSwapFee(address pool, bool swap0To1) private view returns (uint24) {
        return swap0To1
            ? IPool(pool).getSwapFee(msg.sender, IPool(pool).token0(), IPool(pool).token1(), abi.encode(0))
            : IPool(pool).getSwapFee(msg.sender, IPool(pool).token1(), IPool(pool).token0(), abi.encode(0));
    }

    /**
     * @dev Converts TokenInput array to IRouter.TokenInput array.
     * @param inputs The TokenInput array.
     * @return IRouter.TokenInput[] The converted IRouter.TokenInput array.
     */
    function _convertToIRouterTokenInput(TokenInput[] memory inputs)
        private
        pure
        returns (IRouter.TokenInput[] memory)
    {
        IRouter.TokenInput[] memory convertedInputs = new IRouter.TokenInput[](inputs.length);

        for (uint256 i = 0; i < inputs.length; i++) {
            convertedInputs[i] = IRouter.TokenInput({token: inputs[i].token, amount: inputs[i].amount});
        }

        return convertedInputs;
    }

    /**
     * @dev Receives ETH deposits.
     */
    receive() external payable {}

    /**
     * @dev Fallback function to revert unexpected transactions.
     */
    fallback() external payable {
        revert("Fallback not allowed");
    }
}
