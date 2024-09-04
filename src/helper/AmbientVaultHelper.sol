// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Zap} from "../utils/Zap.sol";
import {FixedPoint} from "../utils/FixedPoint.sol";

import {ICrocQuery} from "../interfaces/ambient/ICrocQuery.sol";
import {ICrocImpact} from "../interfaces/ambient/ICrocImpact.sol";
import {ICrocSwapDex} from "../interfaces/ambient/ICrocSwapDex.sol";
import {IVault} from "../interfaces/lazyotter/IVault.sol";
import {IWETH} from "../interfaces/lazyotter/IWETH.sol";

/**
 * @title AmbientVaultHelper
 * @dev Helper contract for interacting with SyncSwap pools and vaults.
 */
contract AmbientVaultHelper is ReentrancyGuard {
    struct TokenInput {
        address token;
        uint256 amount;
    }

    struct PoolInfo {
        address quoteToken;
        uint128 quoteTokenAmount;
        address baseToken;
        uint128 baseTokenAmount;
    }

    struct LimitPrice {
        uint128 lower;
        uint128 upper;
    }

    struct RemoveLiquidityParams {
        bool isBase;
        uint128 minOut;
    }

    using SafeERC20 for IERC20;
    using Address for address;

    /// @notice The address representing native ETH.
    address public constant NATIVE_ETH = address(0);
    /// @notice The maximum fee constant.
    uint256 public constant MAX_FEE = 1_000_000;
    /// @notice The scale factor constant in order to prevent overflow.
    uint256 public constant SCALE_FACTOR = 1_000;

    /// @notice
    ICrocSwapDex public crocSwapDex;
    ICrocQuery public crocQuery;
    ICrocImpact public crocImpact;

    constructor(ICrocSwapDex _crocSwapDex, ICrocQuery _crocQuery, ICrocImpact _crocImpact) {
        require(address(_crocSwapDex) != address(0) && address(_crocQuery) != address(0), "INVALID_ADDRESS");
        crocSwapDex = _crocSwapDex;
        crocQuery = _crocQuery;
        crocImpact = _crocImpact;
    }

    function previewDeposit(address vault, uint256 assets) public view returns (uint256) {
        return IVault(vault).previewDeposit(assets);
    }

    function previewWithdraw(address vault, uint256 assets) public view returns (uint256) {
        return IVault(vault).previewWithdraw(assets);
    }

    function previewRedeem(address vault, uint256 shares) public view returns (uint256) {
        return IVault(vault).previewRedeem(shares);
    }

    function previewAmountByAsset(address vault, uint256 assets)
        public
        view
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        uint128 price = crocQuery.queryPrice(IVault(vault).baseToken(), IVault(vault).quoteToken(), 420);
        uint128 liquidity = _safeConvertUint256ToUint128(_getRealLiquidity(vault, assets));

        uint192 quoteQty = FixedPoint.divQ64(liquidity, price);
        uint192 baseQty = FixedPoint.mulQ64(liquidity, price);

        return (uint256(quoteQty), uint256(baseQty));
    }

    function previewAmountByShare(address vault, uint256 shares)
        public
        view
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        uint256 assets = previewRedeem(vault, shares);

        uint128 price = crocQuery.queryPrice(IVault(vault).baseToken(), IVault(vault).quoteToken(), 420);
        uint128 liquidity = _safeConvertUint256ToUint128(_getRealLiquidity(vault, assets));

        uint192 quoteQty = FixedPoint.divQ64(liquidity, price);
        uint192 baseQty = FixedPoint.mulQ64(liquidity, price);

        return (uint256(quoteQty), uint256(baseQty));
    }

    function previewSingleAmountByAsset(address vault, uint256 assets, bool isBase)
        public
        view
        returns (uint256 tokenAmount)
    {
        address baseToken = IVault(vault).baseToken();
        address quoteToken = IVault(vault).quoteToken();

        (uint256 quoteTokenAmount, uint256 baseTokenAmount) = previewAmountByAsset(vault, assets);

        if (isBase) {
            if (quoteTokenAmount > 0) {
                (int128 baseFlow,,) = crocImpact.calcImpact(
                    baseToken,
                    quoteToken,
                    420,
                    false, // isBuy: false because we're selling quote for base
                    false, // inBaseQty: false because we're inputting quote amount
                    _safeConvertUint256ToUint128(quoteTokenAmount),
                    0, // tip: 0 for standard fee
                    0 // limitPrice: 0 for no limit
                );
                return uint256(baseTokenAmount) + uint256(uint128(-baseFlow));
            }
            return baseTokenAmount;
        } else {
            if (baseTokenAmount > 0) {
                (, int128 quoteFlow,) = crocImpact.calcImpact(
                    baseToken,
                    quoteToken,
                    420,
                    true, // isBuy: true because we're selling base for quote
                    true, // inBaseQty: true because we're inputting base amount
                    _safeConvertUint256ToUint128(baseTokenAmount),
                    0, // tip: 0 for standard fee
                    type(uint128).max // limitPrice: max for no limit
                );
                return uint256(quoteTokenAmount) + uint256(uint128(-quoteFlow));
            }
        }
    }

    function previewSingleAmountByShare(address vault, uint256 shares, bool isBase)
        public
        view
        returns (uint256 tokenAmount)
    {
        address baseToken = IVault(vault).baseToken();
        address quoteToken = IVault(vault).quoteToken();

        (uint256 quoteTokenAmount, uint256 baseTokenAmount) = previewAmountByShare(vault, shares);

        if (isBase) {
            if (quoteTokenAmount > 0) {
                (int128 baseFlow,,) = crocImpact.calcImpact(
                    baseToken,
                    quoteToken,
                    420,
                    false, // isBuy: false because we're selling quote for base
                    false, // inBaseQty: false because we're inputting quote amount
                    _safeConvertUint256ToUint128(quoteTokenAmount),
                    0, // tip: 0 for standard fee
                    0 // limitPrice: 0 for no limit
                );
                return uint256(baseTokenAmount) + uint256(uint128(-baseFlow));
            }
            return baseTokenAmount;
        } else {
            if (baseTokenAmount > 0) {
                (, int128 quoteFlow,) = crocImpact.calcImpact(
                    baseToken,
                    quoteToken,
                    420,
                    true, // isBuy: true because we're selling base for quote
                    true, // inBaseQty: true because we're inputting base amount
                    _safeConvertUint256ToUint128(baseTokenAmount),
                    0, // tip: 0 for standard fee
                    type(uint128).max // limitPrice: max for no limit
                );
                return uint256(quoteTokenAmount) + uint256(uint128(-quoteFlow));
            }
        }
    }

    function deposit(
        TokenInput[] calldata inputs,
        LimitPrice calldata limitPrice,
        uint128 minOut,
        address vault,
        address receiver
    ) external payable returns (uint256) {
        require(inputs.length < 3, "TOO_MANY_INPUT_TOKENS");
        if (inputs.length == 2) {
            require(inputs[0].token != inputs[1].token, "DUPLICATE_TOKENS");
        }

        // quote token: x, base token: y, native ETH will always be the base token
        PoolInfo memory poolInfo = PoolInfo({
            quoteToken: IVault(vault).quoteToken(),
            quoteTokenAmount: _getPoolQuoteTokenAmount(vault),
            baseToken: IVault(vault).baseToken(),
            baseTokenAmount: _getPoolBaseTokenAmount(vault)
        });

        for (uint8 i = 0; i < inputs.length; i++) {
            _transferFromSender(inputs[i].token, inputs[i].amount);
        }
        TokenInput[] memory normalizedInputs = _normalizeTokenInput(vault, inputs);

        // this function will modify the value of normalizedInputs
        _zap(normalizedInputs, limitPrice, poolInfo, minOut);

        if (poolInfo.baseToken == NATIVE_ETH) {
            IERC20(normalizedInputs[0].token).approve(address(crocSwapDex), normalizedInputs[0].amount);
        } else {
            IERC20(normalizedInputs[0].token).approve(address(crocSwapDex), normalizedInputs[0].amount);
            IERC20(normalizedInputs[1].token).approve(address(crocSwapDex), normalizedInputs[1].amount);
        }

        poolInfo.quoteTokenAmount = _getPoolQuoteTokenAmount(vault);
        poolInfo.baseTokenAmount = _getPoolBaseTokenAmount(vault);

        bytes memory returnMsg;
        // if the x y ratio in the pool is greater than the x y ratio in the inputs, add liquidity fixed in X token(quote token)
        if (
            uint256(poolInfo.quoteTokenAmount) * normalizedInputs[1].amount
                > uint256(poolInfo.baseTokenAmount) * normalizedInputs[0].amount
        ) {
            returnMsg = _addLiquidity(
                32, // fixed in quote tokens
                poolInfo,
                normalizedInputs,
                _safeConvertUint256ToUint128(normalizedInputs[0].amount),
                limitPrice,
                vault
            );
        } else {
            returnMsg = _addLiquidity(
                31, // fixed in base tokens
                poolInfo,
                normalizedInputs,
                _safeConvertUint256ToUint128(normalizedInputs[1].amount),
                limitPrice,
                vault
            );
        }

        // this function will modify the value of normalizedInputs
        _refund(normalizedInputs, returnMsg);

        // deposit LP token to vault and mint share token to user
        uint256 lpTokenAmount = IERC20(IVault(vault).asset()).balanceOf(address(this));
        IERC20(IVault(vault).asset()).approve(vault, lpTokenAmount);
        uint256 shares = IVault(vault).deposit(lpTokenAmount, receiver);

        return shares;
    }

    function redeem(LimitPrice calldata limitPrice, address vault, uint256 shares, address receiver)
        external
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        PoolInfo memory poolInfo = PoolInfo({
            quoteToken: IVault(vault).quoteToken(),
            quoteTokenAmount: _getPoolQuoteTokenAmount(vault),
            baseToken: IVault(vault).baseToken(),
            baseTokenAmount: _getPoolBaseTokenAmount(vault)
        });
        uint256 liquidity = IVault(vault).redeem(shares, address(this), msg.sender);

        IERC20(IVault(vault).asset()).approve(address(crocSwapDex), liquidity);
        bytes memory returnMsg = _removeLiquidity(
            poolInfo, _safeConvertUint256ToUint128(_getRealLiquidity(vault, liquidity)), limitPrice, vault
        );

        (int256 baseTokenFlow, int256 quoteTokenFlow) = abi.decode(returnMsg, (int256, int256));

        _transferTo(receiver, IVault(vault).quoteToken(), uint256(-quoteTokenFlow));
        _transferTo(receiver, IVault(vault).baseToken(), uint256(-baseTokenFlow));

        return (uint256(-quoteTokenFlow), uint256(-baseTokenFlow));
    }

    function redeemSingle(
        LimitPrice calldata limitPrice,
        RemoveLiquidityParams calldata params,
        address vault,
        uint256 shares,
        address receiver
    ) external returns (uint256) {
        PoolInfo memory poolInfo = PoolInfo({
            quoteToken: IVault(vault).quoteToken(),
            quoteTokenAmount: _getPoolQuoteTokenAmount(vault),
            baseToken: IVault(vault).baseToken(),
            baseTokenAmount: _getPoolBaseTokenAmount(vault)
        });
        uint256 liquidity = IVault(vault).redeem(shares, address(this), msg.sender);

        IERC20(IVault(vault).asset()).approve(address(crocSwapDex), liquidity);
        bytes memory returnMsg = _removeLiquidity(
            poolInfo, _safeConvertUint256ToUint128(_getRealLiquidity(vault, liquidity)), limitPrice, vault
        );

        (int256 baseTokenFlow, int256 quoteTokenFlow) = abi.decode(returnMsg, (int256, int256));

        if (params.isBase == true) {
            // quote token -> base token
            IERC20(poolInfo.quoteToken).approve(address(crocSwapDex), uint256(-quoteTokenFlow));

            returnMsg = _swap(
                poolInfo,
                false,
                false,
                _safeConvertUint256ToUint128(uint256(-quoteTokenFlow)),
                limitPrice.lower,
                params.minOut
            );

            (int256 swapBaseTokenFlow,) = abi.decode(returnMsg, (int256, int256));
            uint256 transferAmount = uint256(-baseTokenFlow) + uint256(-swapBaseTokenFlow);

            _transferTo(receiver, IVault(vault).baseToken(), transferAmount);
            return (transferAmount);
        } else {
            // base token -> quote token
            if (poolInfo.baseToken != NATIVE_ETH) {
                IERC20(poolInfo.baseToken).approve(address(crocSwapDex), uint256(-baseTokenFlow));
            }

            returnMsg = _swap(
                poolInfo,
                true,
                true,
                _safeConvertUint256ToUint128(uint256(-baseTokenFlow)),
                limitPrice.upper,
                params.minOut
            );

            (, int256 swapQuoteTokenFlow) = abi.decode(returnMsg, (int256, int256));
            uint256 transferAmount = uint256(-quoteTokenFlow) + uint256(-swapQuoteTokenFlow);

            _transferTo(receiver, IVault(vault).quoteToken(), transferAmount);
            return (transferAmount);
        }
    }

    function withdraw(LimitPrice calldata limitPrice, address vault, uint256 assets, address receiver)
        external
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        IVault(vault).withdraw(assets, address(this), msg.sender);

        IERC20(IVault(vault).asset()).approve(address(crocSwapDex), assets);
        bytes memory returnMsg = _removeLiquidity(
            PoolInfo({
                quoteToken: IVault(vault).quoteToken(),
                quoteTokenAmount: _getPoolQuoteTokenAmount(vault),
                baseToken: IVault(vault).baseToken(),
                baseTokenAmount: _getPoolBaseTokenAmount(vault)
            }),
            _safeConvertUint256ToUint128(_getRealLiquidity(vault, assets)),
            limitPrice,
            vault
        );

        (int256 baseTokenFlow, int256 quoteTokenFlow) = abi.decode(returnMsg, (int256, int256));

        _transferTo(receiver, IVault(vault).quoteToken(), uint256(-quoteTokenFlow));
        _transferTo(receiver, IVault(vault).baseToken(), uint256(-baseTokenFlow));

        return (uint256(-quoteTokenFlow), uint256(-baseTokenFlow));
    }

    function withdrawSingle(
        LimitPrice calldata limitPrice,
        RemoveLiquidityParams calldata params,
        address vault,
        uint256 assets,
        address receiver
    ) external returns (uint256) {
        PoolInfo memory poolInfo = PoolInfo({
            quoteToken: IVault(vault).quoteToken(),
            quoteTokenAmount: _getPoolQuoteTokenAmount(vault),
            baseToken: IVault(vault).baseToken(),
            baseTokenAmount: _getPoolBaseTokenAmount(vault)
        });
        IVault(vault).withdraw(assets, address(this), msg.sender);

        IERC20(IVault(vault).asset()).approve(address(crocSwapDex), assets);
        bytes memory returnMsg = _removeLiquidity(
            poolInfo, _safeConvertUint256ToUint128(_getRealLiquidity(vault, assets)), limitPrice, vault
        );

        (int256 baseTokenFlow, int256 quoteTokenFlow) = abi.decode(returnMsg, (int256, int256));

        if (params.isBase == true) {
            // quote token -> base token
            IERC20(poolInfo.quoteToken).approve(address(crocSwapDex), uint256(-quoteTokenFlow));

            returnMsg = _swap(
                poolInfo,
                false,
                false,
                _safeConvertUint256ToUint128(uint256(-quoteTokenFlow)),
                limitPrice.lower,
                params.minOut
            );

            (int256 swapBaseTokenFlow,) = abi.decode(returnMsg, (int256, int256));
            uint256 transferAmount = uint256(-baseTokenFlow) + uint256(-swapBaseTokenFlow);

            _transferTo(receiver, IVault(vault).baseToken(), transferAmount);
            return (transferAmount);
        } else {
            // base token -> quote token
            if (poolInfo.baseToken != NATIVE_ETH) {
                IERC20(poolInfo.baseToken).approve(address(crocSwapDex), uint256(-baseTokenFlow));
            }

            returnMsg = _swap(
                poolInfo,
                true,
                true,
                _safeConvertUint256ToUint128(uint256(-baseTokenFlow)),
                limitPrice.upper,
                params.minOut
            );

            (, int256 swapQuoteTokenFlow) = abi.decode(returnMsg, (int256, int256));
            uint256 transferAmount = uint256(-quoteTokenFlow) + uint256(-swapQuoteTokenFlow);

            _transferTo(receiver, IVault(vault).quoteToken(), transferAmount);
            return (transferAmount);
        }
    }

    function _removeLiquidity(PoolInfo memory poolInfo, uint128 amount, LimitPrice memory limitPrice, address vault)
        private
        returns (bytes memory)
    {
        return crocSwapDex.userCmd(
            uint16(128),
            abi.encode(
                4, // fixed in liquidity units
                poolInfo.baseToken,
                poolInfo.quoteToken,
                uint256(420), // poolIdx
                int24(0), // bidTick, ignore if it's ambient liquidity
                int24(0), // askTick, ignore if it's ambient liquidity
                amount,
                limitPrice.lower,
                limitPrice.upper,
                uint8(0), // settleFlags
                address(IVault(vault).asset())
            )
        );
    }

    function _refund(TokenInput[] memory inputs, bytes memory returnMsg) private {
        (int256 baseTokenFlow, int256 quoteTokenFlow) = abi.decode(returnMsg, (int256, int256));

        inputs[0].amount = _safeSubUint256AndInt256(inputs[0].amount, quoteTokenFlow);
        inputs[1].amount = _safeSubUint256AndInt256(inputs[1].amount, baseTokenFlow);

        // if there is any remaining token, refund it to the user
        for (uint8 i = 0; i < inputs.length; i++) {
            if (inputs[i].amount > 0) {
                _transferTo(msg.sender, inputs[i].token, inputs[i].amount);
            }
        }

        // no need to set inputs amount to 0, because it won't need to be used anymore
    }

    function _zap(TokenInput[] memory inputs, LimitPrice memory limitPrice, PoolInfo memory poolInfo, uint128 minOut)
        private
    {
        // n * y > m * x
        bool swap0To1 = inputs[0].amount * poolInfo.baseTokenAmount > inputs[1].amount * poolInfo.quoteTokenAmount;
        // The maximum fee constant in Ambient is 1_000_000
        uint16 swapFee = _getSwapFee(poolInfo);

        // estimate deltaX, could be wrong if the liquidity in current price tick is not enough, will refund the extra amount to user
        uint256 deltaX;
        if (swap0To1) {
            deltaX = Zap.getDeltaX(
                poolInfo.quoteTokenAmount / SCALE_FACTOR,
                poolInfo.baseTokenAmount / SCALE_FACTOR,
                inputs[0].amount / SCALE_FACTOR,
                inputs[1].amount / SCALE_FACTOR,
                swapFee,
                MAX_FEE
            ) * SCALE_FACTOR;
        } else {
            deltaX = Zap.getDeltaX(
                poolInfo.baseTokenAmount / SCALE_FACTOR,
                poolInfo.quoteTokenAmount / SCALE_FACTOR,
                inputs[1].amount / SCALE_FACTOR,
                inputs[0].amount / SCALE_FACTOR,
                swapFee,
                MAX_FEE
            ) * SCALE_FACTOR;
        }

        bytes memory returnBytes;
        int256 quoteTokenFlow;
        int256 baseTokenFlow;
        // swap if deltaX is not 0, native ETH will always be the base token, so there is only possible to send eth if swap0To1 == false
        if (deltaX != 0 && swap0To1) {
            // quote token -> base token
            // in this case(swap0To1 == true), quoteTokenFlow is positive, baseTokenFlow is negative
            IERC20(inputs[0].token).approve(address(crocSwapDex), deltaX);
            returnBytes = _swap(poolInfo, false, false, _safeConvertUint256ToUint128(deltaX), limitPrice.lower, minOut);
            (baseTokenFlow, quoteTokenFlow) = abi.decode(returnBytes, (int256, int256));

            inputs[0].amount = _safeSubUint256AndInt256(inputs[0].amount, quoteTokenFlow);
            inputs[1].amount = _safeSubUint256AndInt256(inputs[1].amount, baseTokenFlow);
        } else if (deltaX != 0 && !swap0To1) {
            // base token -> quote token
            // in this case(swap0To1 == false), quoteTokenFlow is negative, baseTokenFlow is positive
            if (inputs[1].token != NATIVE_ETH) {
                IERC20(inputs[1].token).approve(address(crocSwapDex), deltaX);
            }

            returnBytes = _swap(poolInfo, true, true, _safeConvertUint256ToUint128(deltaX), limitPrice.upper, minOut);
            (baseTokenFlow, quoteTokenFlow) = abi.decode(returnBytes, (int128, int128));

            inputs[0].amount = _safeSubUint256AndInt256(inputs[0].amount, quoteTokenFlow);
            inputs[1].amount = _safeSubUint256AndInt256(inputs[1].amount, baseTokenFlow);
        }
    }

    function _swap(
        PoolInfo memory poolInfo,
        bool isBuy,
        bool inBaseQty,
        uint128 qty,
        uint128 limitPrice,
        uint128 minOut
    ) private returns (bytes memory) {
        if (poolInfo.baseToken == NATIVE_ETH && isBuy == true) {
            return crocSwapDex.userCmd{value: qty}(
                uint16(1),
                abi.encode(
                    poolInfo.baseToken,
                    poolInfo.quoteToken,
                    uint256(420),
                    isBuy,
                    inBaseQty,
                    qty,
                    uint16(0),
                    limitPrice,
                    minOut,
                    uint8(0)
                )
            );
        } else {
            return crocSwapDex.userCmd(
                uint16(1),
                abi.encode(
                    poolInfo.baseToken,
                    poolInfo.quoteToken,
                    uint256(420),
                    isBuy,
                    inBaseQty,
                    qty,
                    uint16(0),
                    limitPrice,
                    minOut,
                    uint8(0)
                )
            );
        }
    }

    function _addLiquidity(
        uint8 code,
        PoolInfo memory poolInfo,
        TokenInput[] memory inputs,
        uint128 amount,
        LimitPrice memory limitPrice,
        address vault
    ) private returns (bytes memory) {
        if (poolInfo.baseToken == NATIVE_ETH) {
            return crocSwapDex.userCmd{value: inputs[1].amount}(
                uint16(128),
                abi.encode(
                    code,
                    poolInfo.baseToken,
                    poolInfo.quoteToken,
                    uint256(420), // poolIdx
                    int24(0), // bidTick, ignore if it's ambient liquidity
                    int24(0), // askTick, ignore if it's ambient liquidity
                    amount,
                    limitPrice.lower,
                    limitPrice.upper,
                    uint8(0), // settleFlags
                    address(IVault(vault).asset())
                )
            );
        } else {
            return crocSwapDex.userCmd(
                uint16(128),
                abi.encode(
                    code,
                    poolInfo.baseToken,
                    poolInfo.quoteToken,
                    uint256(420), // poolIdx
                    int24(0), // bidTick, ignore if it's ambient liquidity
                    int24(0), // askTick, ignore if it's ambient liquidity
                    amount,
                    limitPrice.lower,
                    limitPrice.upper,
                    uint8(0), // settleFlags
                    address(IVault(vault).asset())
                )
            );
        }
    }

    function _transferFromSender(address token, uint256 amount) private {
        if (token == NATIVE_ETH) {
            require(msg.value == amount, "ETH_AMOUNT_MISMATCH");
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _transferTo(address receiver, address token, uint256 amount) private nonReentrant {
        if (token == NATIVE_ETH) {
            (bool sent,) = receiver.call{value: amount}("");
            require(sent, "FAILED_TO_SEND_ETHER");
        } else {
            IERC20(token).safeTransfer(receiver, amount);
        }
    }

    function _normalizeTokenInput(address vault, TokenInput[] memory inputs)
        private
        view
        returns (TokenInput[] memory)
    {
        TokenInput[] memory normalizedInputs = new TokenInput[](2);
        uint256 quoteTokenAmount = 0;
        uint256 baseTokenAmount = 0;

        for (uint8 i = 0; i < inputs.length; i++) {
            if (inputs[i].token == IVault(vault).quoteToken()) {
                quoteTokenAmount = inputs[i].amount;
            } else if (inputs[i].token == IVault(vault).baseToken()) {
                baseTokenAmount = inputs[i].amount;
            } else {
                revert();
            }
        }

        normalizedInputs[0] = TokenInput({token: IVault(vault).quoteToken(), amount: quoteTokenAmount});
        normalizedInputs[1] = TokenInput({token: IVault(vault).baseToken(), amount: baseTokenAmount});

        return normalizedInputs;
    }

    function _getSwapFee(PoolInfo memory poolInfo) private view returns (uint16) {
        ICrocQuery.Pool memory pool = crocQuery.queryPoolParams(poolInfo.baseToken, poolInfo.quoteToken, 420);
        return pool.feeRate_;
    }

    function _getPoolQuoteTokenAmount(address vault) private view returns (uint128) {
        return uint128(
            FixedPoint.divQ64(
                crocQuery.queryLiquidity(IVault(vault).baseToken(), IVault(vault).quoteToken(), 420),
                crocQuery.queryPrice(IVault(vault).baseToken(), IVault(vault).quoteToken(), 420)
            )
        );
    }

    function _getPoolBaseTokenAmount(address vault) private view returns (uint128) {
        return uint128(
            FixedPoint.mulQ64(
                crocQuery.queryLiquidity(IVault(vault).baseToken(), IVault(vault).quoteToken(), 420),
                crocQuery.queryPrice(IVault(vault).baseToken(), IVault(vault).quoteToken(), 420)
            )
        );
    }

    function _getRealLiquidity(address vault, uint256 liquidity) private view returns (uint256) {
        ICrocQuery.CurveState memory curve =
            crocQuery.queryCurve(IVault(vault).baseToken(), IVault(vault).quoteToken(), 420);
        uint64 deflator = curve.seedDeflator_;

        uint64 ONE = uint64(FixedPoint.Q48);
        uint128 uint128Liq = _safeConvertUint256ToUint128(liquidity);
        uint144 realLiquidity = FixedPoint.mulQ48(uint128Liq, ONE + deflator);

        return uint256(realLiquidity);
    }

    function _safeConvertUint256ToUint128(uint256 _value) private pure returns (uint128) {
        require(_value <= type(uint128).max, "VALUE_EXCEEDS_UINT128");
        return uint128(_value);
    }

    function _safeSubUint256AndInt256(uint256 a, int256 b) private pure returns (uint256) {
        int256 result = int256(uint256(a)) - int256(b);
        require(result >= 0, "SUB_OVERFLOW");
        return uint256(result);
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
