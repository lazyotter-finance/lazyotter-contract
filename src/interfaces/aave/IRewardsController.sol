// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IRewardsController {
    function claimRewards(address[] calldata assets, uint256 amount, address to, address reward)
        external
        returns (uint256);

    function getUserRewards(address[] calldata assets, address user, address reward) external view returns (uint256);

    function claimAllRewardsToSelf(address[] calldata assets)
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
}
