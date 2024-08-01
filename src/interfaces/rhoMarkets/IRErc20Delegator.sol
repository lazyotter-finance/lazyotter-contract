// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRErc20Delegator {
    // Events
    event AccrueInterest(uint256 cashPrior, uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);
    event LiquidateBorrow(
        address liquidator,
        address borrower,
        uint256 repayAmount,
        address rTokenCollateral,
        uint256 seizeTokens
    );
    event Mint(address minter, uint256 mintAmount, uint256 mintTokens);
    event NewAdmin(address oldAdmin, address newAdmin);
    event NewComptroller(address oldComptroller, address newComptroller);
    event NewImplementation(address oldImplementation, address newImplementation);
    event NewMarketInterestRateModel(address oldInterestRateModel, address newInterestRateModel);
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
    event NewProtocolSeizeShare(uint256 oldProtocolSeizeShareMantissa, uint256 newProtocolSeizeShareMantissa);
    event NewRedemptionReserveFactor(uint256 oldRedemptionReserveFactor, uint256 newRedemptionReserveFactor);
    event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);
    event Redeem(address redeemer, uint256 redeemAmount, uint256 redeemTokens);
    event RepayBorrow(
        address payer,
        address borrower,
        uint256 repayAmount,
        uint256 accountBorrows,
        uint256 totalBorrows
    );
    event ReservesAdded(address benefactor, uint256 addAmount, uint256 newTotalReserves);
    event ReservesReduced(address admin, uint256 reduceAmount, uint256 newTotalReserves);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    // Admin Functions
    function _acceptAdmin() external returns (uint256);
    function _addReserves(uint256 addAmount) external returns (uint256);
    function _reduceReserves(uint256 reduceAmount) external returns (uint256);
    function _setComptroller(address newComptroller) external returns (uint256);
    function _setImplementation(
        address implementation_,
        bool allowResign,
        bytes calldata becomeImplementationData
    ) external;
    function _setInterestRateModel(address newInterestRateModel) external returns (uint256);
    function _setPendingAdmin(address newPendingAdmin) external returns (uint256);
    function _setProtocolSeizeShare(uint256 newProtocolSeizeShareMantissa) external returns (uint256);
    function _setReserveFactor(uint256 newReserveFactorMantissa) external returns (uint256);

    // Public Functions
    function accrualBlockNumber() external view returns (uint256);
    function accrueInterest() external returns (uint256);
    function admin() external view returns (address payable);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function balanceOfUnderlying(address owner) external returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
    function borrowBalanceCurrent(address account) external returns (uint256);
    function borrowBalanceStored(address account) external view returns (uint256);
    function borrowIndex() external view returns (uint256);
    function borrowRatePerBlock() external view returns (uint256);
    function comptroller() external view returns (address);
    function decimals() external view returns (uint8);
    function delegateToImplementation(bytes memory data) external returns (bytes memory);
    function delegateToViewImplementation(bytes memory data) external view returns (bytes memory);
    function exchangeRateCurrent() external returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);
    function getCash() external view returns (uint256);
    function implementation() external view returns (address);
    function interestRateModel() external view returns (address);
    function isEthDerivative() external view returns (bool);
    function isRToken() external view returns (bool);
    function liquidateBorrow(
        address borrower,
        uint256 repayAmount,
        address rTokenCollateral
    ) external returns (uint256);
    function mint(uint256 mintAmount) external returns (uint256);
    function mintWithPermit(
        uint256 mintAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);
    function name() external view returns (string memory);
    function pendingAdmin() external view returns (address payable);
    function protocolSeizeShareMantissa() external view returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function repayBorrow(uint256 repayAmount) external returns (uint256);
    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);
    function reserveFactorMantissa() external view returns (uint256);
    function seize(address liquidator, address borrower, uint256 seizeTokens) external returns (uint256);
    function supplyRatePerBlock() external view returns (uint256);
    function sweepToken(address token) external;
    function symbol() external view returns (string memory);
    function totalBorrows() external view returns (uint256);
    function totalBorrowsCurrent() external returns (uint256);
    function totalReserves() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address dst, uint256 amount) external returns (bool);
    function transferFrom(address src, address dst, uint256 amount) external returns (bool);
    function underlying() external view returns (address);
}
