// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Arrays} from "../utils/Arrays.sol";

/**
 * @title Vault
 * @dev A vault contract for managing deposits, withdrawals, and fee distribution.
 */
contract Vault is ERC20, ReentrancyGuard, AccessControl, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using Arrays for uint256[];

    struct FeeInfo {
        address[] recipients;
        uint256[] recipientWeights;
        uint256 harvesterWeight;
        uint256 harvestFeeRate;
        uint256 withdrawalFeeRate;
    }

    /// @notice The underlying asset of the vault.
    IERC20 public immutable asset;

    /// @notice Maximum fee rate constant.
    uint256 public constant MAX_FEE_RATE = 10000;

    /// @notice Information about fees.
    FeeInfo public feeInfo;

    /// @notice Total weight of fee recipients.
    uint256 public totalRecipientsWeight;

    /// @notice Role for keeper.
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    /// @notice Emitted when a deposit is made.
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    /// @notice Emitted when a withdrawal is made.
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    /// @notice Emitted when a harvest is performed.
    event Harvest(address indexed caller, uint256 harvestAssets);

    /**
     * @dev Constructor for the Vault contract.
     * @param _asset The underlying asset of the vault.
     * @param name The name of the ERC20 token.
     * @param symbol The symbol of the ERC20 token.
     * @param _feeInfo The initial fee information.
     * @param _keeper The address of the keeper.
     */
    constructor(IERC20 _asset, string memory name, string memory symbol, FeeInfo memory _feeInfo, address _keeper)
        ERC20(name, symbol)
    {
        asset = _asset;

        // role
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(KEEPER_ROLE, DEFAULT_ADMIN_ROLE);
        _grantRole(KEEPER_ROLE, _keeper);

        setFeeInfo(_feeInfo);
    }

    /**
     * @dev Modifier to check if the caller is the owner.
     */
    modifier onlyOwner() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    /**
     * @dev Modifier to check if the caller is the owner or keeper.
     */
    modifier onlyOwnerOrKeeper() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(KEEPER_ROLE, msg.sender), "Permissions denied");
        _;
    }

    /**
     * @notice Returns the number of decimals used to get its user representation.
     * @return uint8 Number of decimals.
     */
    function decimals() public view override returns (uint8) {
        return ERC20(address(asset)).decimals() + _decimalsOffset();
    }

    /**
     * @notice Returns the total assets held by the vault.
     * @return uint256 Total assets.
     */
    function totalAssets() public view virtual returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /**
     * @notice Returns the maximum amount that can be deposited.
     * @param account The address of the account.
     * @return uint256 Maximum deposit amount.
     */
    function maxDeposit(address account) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @notice Returns the maximum amount of shares that can be minted.
     * @param receiver The address of the receiver.
     * @return uint256 Maximum mint amount.
     */
    function maxMint(address receiver) public view returns (uint256) {
        uint256 _maxDeposit = maxDeposit(receiver);
        if (_maxDeposit == type(uint256).max) {
            return type(uint256).max;
        }
        return _convertToShares(_maxDeposit, Math.Rounding.Floor);
    }

    /**
     * @notice Returns the maximum amount that can be withdrawn.
     * @param owner The address of the owner.
     * @return uint256 Maximum withdraw amount.
     */
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return _convertToAssets(balanceOf(owner), Math.Rounding.Ceil);
    }

    /**
     * @notice Returns the maximum amount of shares that can be redeemed.
     * @param owner The address of the owner.
     * @return uint256 Maximum redeem amount.
     */
    function maxRedeem(address owner) public view returns (uint256) {
        return _convertToShares(maxWithdraw(owner), Math.Rounding.Floor);
    }

    /**
     * @notice Returns the preview amount of shares for a given deposit of assets.
     * @param assets The amount of assets to deposit.
     * @return uint256 Preview shares.
     */
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /**
     * @notice Returns the preview amount of assets for a given mint of shares.
     * @param shares The amount of shares to mint.
     * @return uint256 Preview assets.
     */
    function previewMint(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    /**
     * @notice Returns the preview amount of shares for a given withdraw of assets.
     * @param assets The amount of assets to withdraw.
     * @return uint256 Preview shares.
     */
    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    /**
     * @notice Returns the preview amount of assets for a given redeem of shares.
     * @param shares The amount of shares to redeem.
     * @return uint256 Preview assets.
     */
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /**
     * @dev Converts a given amount of assets to shares.
     * @param assets The amount of assets.
     * @param rounding The rounding direction.
     * @return uint256 Converted shares.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    /**
     * @dev Converts a given amount of shares to assets.
     * @param shares The amount of shares.
     * @param rounding The rounding direction.
     * @return uint256 Converted assets.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    /**
     * @dev Returns the decimal offset.
     * @return uint8 Decimal offset.
     */
    function _decimalsOffset() internal pure returns (uint8) {
        return 6;
    }

    /**
     * @notice Deposits a given amount of assets into the vault.
     * @param assets The amount of assets to deposit.
     * @param receiver The address of the receiver.
     * @return uint256 Amount of shares minted.
     */
    function deposit(uint256 assets, address receiver) external nonReentrant whenNotPaused returns (uint256) {
        uint256 shares = previewDeposit(assets);
        require(shares > 0, "ZERO_SHARES");

        _mint(receiver, shares);
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _deposit(receiver, assets);

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    /**
     * @notice Mints a given amount of shares to the receiver.
     * @param shares The amount of shares to mint.
     * @param receiver The address of the receiver.
     * @return uint256 Amount of assets deposited.
     */
    function mint(uint256 shares, address receiver) external nonReentrant whenNotPaused returns (uint256) {
        uint256 assets = previewMint(shares);

        _mint(receiver, shares);
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _deposit(receiver, assets);

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    /**
     * @notice Withdraws a given amount of assets from the vault.
     * @param assets The amount of assets to withdraw.
     * @param receiver The address of the receiver.
     * @param owner The address of the owner.
     * @return uint256 Amount of shares burned.
     */
    function withdraw(uint256 assets, address receiver, address owner) external nonReentrant returns (uint256) {
        uint256 shares = previewWithdraw(assets);
        require(shares > 0, "WITHDRAW_ZERO_SHARES");

        uint256 maxAssets = maxWithdraw(owner);
        require(assets <= maxAssets, "WITHDRAW_OVER_MAXASSETS");

        address[] memory recipients = feeInfo.recipients;
        uint256[] memory recipientWeights = feeInfo.recipientWeights;

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burn(owner, shares);
        _withdraw(owner, assets);
        uint256 transferAssets = 0;
        uint256 withdrawalFee = assets * feeInfo.withdrawalFeeRate / MAX_FEE_RATE;
        if (withdrawalFee > 0) {
            uint256 length = recipients.length;
            for (uint256 i = 0; i < length; ++i) {
                transferAssets = (withdrawalFee * recipientWeights[i]) / totalRecipientsWeight;
                if (transferAssets == 0) continue;
                asset.safeTransfer(recipients[i], transferAssets);
            }
            assets -= withdrawalFee;
        }
        asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }

    /**
     * @notice Redeems a given amount of shares for assets.
     * @param shares The amount of shares to redeem.
     * @param receiver The address of the receiver.
     * @param owner The address of the owner.
     * @return uint256 Amount of assets redeemed.
     */
    function redeem(uint256 shares, address receiver, address owner) external nonReentrant returns (uint256) {
        address[] memory recipients = feeInfo.recipients;
        uint256[] memory recipientWeights = feeInfo.recipientWeights;
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        uint256 assets = previewRedeem(shares);
        require(assets > 0, "ZERO_ASSETS");

        _burn(owner, shares);
        _withdraw(owner, assets);
        uint256 transferAssets = 0;
        uint256 withdrawalFee = assets * feeInfo.withdrawalFeeRate / MAX_FEE_RATE;
        if (withdrawalFee > 0) {
            uint256 length = recipients.length;
            for (uint256 i = 0; i < length; ++i) {
                transferAssets = (withdrawalFee * recipientWeights[i]) / totalRecipientsWeight;
                if (transferAssets == 0) continue;
                asset.safeTransfer(recipients[i], transferAssets);
            }
            assets -= withdrawalFee;
        }

        asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return assets;
    }

    /**
     * @notice Harvests assets for the caller.
     * @param caller The address of the caller.
     * @return uint256 Amount of assets harvested.
     */
    function harvest(address caller) external nonReentrant returns (uint256) {
        return _harvest(caller);
    }

    /**
     * @notice Harvests assets for the message sender.
     * @return uint256 Amount of assets harvested.
     */
    function harvest() external nonReentrant returns (uint256) {
        return _harvest(msg.sender);
    }

    /**
     * @dev Internal function to handle asset harvesting.
     * @param caller The address of the caller.
     * @return uint256 Amount of assets harvested.
     */
    function _harvest(address caller) internal returns (uint256) {
        uint256 harvestAssets = _harvest();

        address[] memory recipients = feeInfo.recipients;
        uint256[] memory recipientWeights = feeInfo.recipientWeights;
        uint256 harvesterWeight = feeInfo.harvesterWeight;
        uint256 harvestFee = harvestAssets * feeInfo.harvestFeeRate / MAX_FEE_RATE;
        uint256 transferAssets = 0;
        if (harvestFee > 0) {
            uint256 length = recipients.length;
            for (uint256 i = 0; i < length; ++i) {
                transferAssets = (harvestFee * recipientWeights[i]) / totalRecipientsWeight + feeInfo.harvesterWeight;
                if (transferAssets == 0) continue;
                asset.safeTransfer(recipients[i], transferAssets);
            }
        }
        transferAssets = (harvestFee * harvesterWeight) / totalRecipientsWeight + feeInfo.harvesterWeight;
        if (transferAssets > 0) {
            asset.safeTransfer(caller, transferAssets);
        }

        harvestAssets -= harvestFee;

        _deposit(address(0), 0);

        emit Harvest(caller, harvestAssets);
        return harvestAssets;
    }

    /**
     * @dev Internal function to handle asset harvesting.
     * @return uint256 Amount of assets harvested.
     */
    function _harvest() internal virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Internal function to handle asset deposits.
     * @param receiver The address of the receiver.
     * @param assets The amount of assets.
     */
    function _deposit(address receiver, uint256 assets) internal virtual {
        return;
    }

    /**
     * @dev Internal function to handle asset withdrawals.
     * @param owner The address of the owner.
     * @param assets The amount of assets.
     */
    function _withdraw(address owner, uint256 assets) internal virtual {
        return;
    }

    /**
     * @notice Pauses the contract.
     */
    function pause() external onlyOwnerOrKeeper {
        _pause();
    }

    /**
     * @notice Unpauses the contract.
     */
    function unpause() external onlyOwnerOrKeeper {
        _unpause();
    }

    /**
     * @notice Sets the fee information.
     * @param _feeInfo The new fee information.
     */
    function setFeeInfo(FeeInfo memory _feeInfo) public onlyOwner {
        require(_feeInfo.recipients.length == _feeInfo.recipientWeights.length, "length error");
        require(_feeInfo.withdrawalFeeRate <= MAX_FEE_RATE, "withdrawalFeeRate error");
        require(_feeInfo.harvestFeeRate <= MAX_FEE_RATE, "harvestFeeRate error");
        feeInfo = FeeInfo({
            recipients: _feeInfo.recipients,
            recipientWeights: _feeInfo.recipientWeights,
            harvesterWeight: _feeInfo.harvesterWeight,
            harvestFeeRate: _feeInfo.harvestFeeRate,
            withdrawalFeeRate: _feeInfo.withdrawalFeeRate
        });
        totalRecipientsWeight = _feeInfo.recipientWeights.sum();
    }

    /**
     * @notice Emergency withdraws all assets.
     */
    function emergencyWithdraw() external onlyOwnerOrKeeper {
        _pause();
        uint256 assets = totalAssets();
        _emergencyWithdraw(assets);
    }

    /**
     * @notice Emergency withdraws a given amount of assets.
     * @param assets The amount of assets to withdraw.
     */
    function emergencyWithdraw(uint256 assets) external onlyOwnerOrKeeper {
        _pause();
        _emergencyWithdraw(assets);
    }

    /**
     * @dev Internal function to handle emergency withdrawals.
     * @param assets The amount of assets.
     */
    function _emergencyWithdraw(uint256 assets) internal {
        _withdraw(address(this), assets);
    }

    /**
     * @notice Executes a transaction.
     * @param _to The address to send the transaction to.
     * @param _value The value to send.
     * @param _data The transaction data.
     * @return bool Indicates if the transaction was successful.
     * @return bytes The result of the transaction.
     */
    function execute(address _to, uint256 _value, bytes calldata _data)
        external
        onlyOwner
        returns (bool, bytes memory)
    {
        (bool success, bytes memory result) = _to.call{value: _value}(_data);
        return (success, result);
    }
}
