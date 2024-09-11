// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IComptroller {
    // Events
    event ActionPaused(string action, bool pauseState);
    event ActionPaused(address rToken, string action, bool pauseState);
    event Failure(uint256 error, uint256 info, uint256 detail);
    event MarketEntered(address rToken, address account);
    event MarketExited(address rToken, address account);
    event MarketListed(address rToken);
    event NewBorrowCap(address indexed rToken, uint256 newBorrowCap);
    event NewBorrowCapGuardian(address oldBorrowCapGuardian, address newBorrowCapGuardian);
    event NewCloseFactor(uint256 oldCloseFactorMantissa, uint256 newCloseFactorMantissa);
    event NewCollateralFactor(address rToken, uint256 oldCollateralFactorMantissa, uint256 newCollateralFactorMantissa);
    event NewLiquidationIncentive(uint256 oldLiquidationIncentiveMantissa, uint256 newLiquidationIncentiveMantissa);
    event NewPauseGuardian(address oldPauseGuardian, address newPauseGuardian);
    event NewPriceOracle(address oldPriceOracle, address newPriceOracle);
    event NewRewardDistributor(address oldRewardDistributor, address newRewardDistributor);
    event NewSupplyCap(address indexed rToken, uint256 newSupplyCap);
    event NewSupplyCapGuardian(address oldSupplyCapGuardian, address newSupplyCapGuardian);

    // Functions
    function _become(address unitroller) external;
    function _rescueFunds(address _tokenAddress, uint256 _amount) external;
    function _setBorrowCapGuardian(address newBorrowCapGuardian) external;
    function _setBorrowPaused(address rToken, bool state) external returns (bool);
    function _setCloseFactor(uint256 newCloseFactorMantissa) external returns (uint256);
    function _setCollateralFactor(address rToken, uint256 newCollateralFactorMantissa) external returns (uint256);
    function _setLiquidationIncentive(uint256 newLiquidationIncentiveMantissa) external returns (uint256);
    function _setMarketBorrowCaps(address[] calldata rTokens, uint256[] calldata newBorrowCaps) external;
    function _setMarketSupplyCaps(address[] calldata rTokens, uint256[] calldata newSupplyCaps) external;
    function _setMintPaused(address rToken, bool state) external returns (bool);
    function _setPauseGuardian(address newPauseGuardian) external returns (uint256);
    function _setPriceOracle(address newOracle) external returns (uint256);
    function _setRewardDistributor(address newRewardDistributor) external;
    function _setSeizePaused(bool state) external returns (bool);
    function _setSupplyCapGuardian(address newSupplyCapGuardian) external;
    function _setTransferPaused(bool state) external returns (bool);
    function _supportMarket(address rToken) external returns (uint256);
    function accountAssets(address, uint256) external view returns (address);
    function admin() external view returns (address);
    function allMarkets(uint256) external view returns (address);
    function borrowAllowed(address rToken, address borrower, uint256 borrowAmount) external returns (uint256);
    function borrowCapGuardian() external view returns (address);
    function borrowCaps(address) external view returns (uint256);
    function borrowGuardianPaused(address) external view returns (bool);
    function checkMembership(address account, address rToken) external view returns (bool);
    function claimReward() external;
    function claimReward(address holder) external;
    function claimReward(address holder, address[] calldata rTokens) external;
    function claimReward(
        address[] calldata holders,
        address[] calldata rTokens,
        bool borrowers,
        bool suppliers
    ) external;
    function closeFactorMantissa() external view returns (uint256);
    function comptrollerImplementation() external view returns (address);
    function enterAllMarkets(address account) external returns (uint256[] memory);
    function enterMarkets(address[] calldata rTokens) external returns (uint256[] memory);
    function exitMarket(address rTokenAddress) external returns (uint256);
    function getAccountLiquidity(address account) external view returns (uint256, uint256, uint256);
    function getAllMarkets() external view returns (address[] memory);
    function getAssetsIn(address account) external view returns (address[] memory);
    function getBlockNumber() external view returns (uint256);
    function getHypotheticalAccountLiquidity(
        address account,
        address rTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    ) external view returns (uint256, uint256, uint256);
    function isComptroller() external view returns (bool);
    function isDeprecated(address rToken) external view returns (bool);
    function isInLiquidateWhiteList(address user) external view returns (bool);
    function liquidatable() external view returns (bool);
    function liquidateBorrowAllowed(
        address rTokenBorrowed,
        address rTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external view returns (uint256);
    function liquidateCalculateSeizeTokens(
        address rTokenBorrowed,
        address rTokenCollateral,
        uint256 actualRepayAmount
    ) external view returns (uint256, uint256);
    function liquidationIncentiveMantissa() external view returns (uint256);
    function liquidatorWhiteList(address) external view returns (bool);
    function markets(address) external view returns (bool isListed, uint256 collateralFactorMantissa);
    function mintAllowed(address rToken, address minter, uint256 mintAmount) external returns (uint256);
    function mintGuardianPaused(address) external view returns (bool);
    function oracle() external view returns (address);
    function pauseGuardian() external view returns (address);
    function pendingAdmin() external view returns (address);
    function pendingComptrollerImplementation() external view returns (address);
    function protocalProtectedAccount(address) external view returns (bool);
    function redeemAllowed(address rToken, address redeemer, uint256 redeemTokens) external returns (uint256);
    function redeemVerify(address rToken, address redeemer, uint256 redeemAmount, uint256 redeemTokens) external pure;
    function repayBorrowAllowed(
        address rToken,
        address payer,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256);
    function rewardDistributor() external view returns (address);
    function seizeAllowed(
        address rTokenCollateral,
        address rTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external returns (uint256);
    function seizeGuardianPaused() external view returns (bool);
    function supplyCapGuardian() external view returns (address);
    function supplyCaps(address) external view returns (uint256);
    function transferAllowed(
        address rToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external returns (uint256);
    function transferGuardianPaused() external view returns (bool);
    function triggerLiquidation(bool state) external;
    function updateLiquidateWhiteList(address user, bool state) external;
    function updateProtocalProtectedAccount(address user, bool state) external;
}
