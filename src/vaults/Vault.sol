// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Arrays} from "../utils/Arrays.sol";

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

    IERC20 public immutable asset;

    uint256 public constant MAX_FEE_RATE = 10000;

    FeeInfo public feeInfo;

    uint256 public totalRecipientsWeight;

    // role
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    event Harvest(address indexed caller, uint256 harvestAssets);

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

    modifier onlyOwner() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    modifier onlyOwnerOrKeeper() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(KEEPER_ROLE, msg.sender), "Permissions denied");
        _;
    }

    function decimals() public view override returns (uint8) {
        return ERC20(address(asset)).decimals();
    }

    function totalAssets() public view virtual returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address receiver) public view returns (uint256) {
        uint256 _maxDeposit = maxDeposit(receiver);
        if (_maxDeposit == type(uint256).max) {
            return type(uint256).max;
        }
        return _convertToShares(_maxDeposit, Math.Rounding.Floor);
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return _convertToAssets(balanceOf(owner), Math.Rounding.Ceil);
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return _convertToShares(maxWithdraw(owner), Math.Rounding.Floor);
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    function _decimalsOffset() internal pure returns (uint8) {
        return 6;
    }

    function deposit(uint256 assets, address receiver) external nonReentrant whenNotPaused returns (uint256) {
        uint256 shares = previewDeposit(assets);
        require(shares > 0, "ZERO_SHARES");

        _mint(receiver, shares);
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _deposit(receiver, assets);

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    function mint(uint256 shares, address receiver) external nonReentrant whenNotPaused returns (uint256) {
        uint256 assets = previewMint(shares);

        _mint(receiver, shares);
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _deposit(receiver, assets);

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

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

    function harvest(address caller) external nonReentrant returns (uint256) {
        return _harvest(caller);
    }

    function harvest() external nonReentrant returns (uint256) {
        return _harvest(msg.sender);
    }

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

    function _harvest() internal virtual returns (uint256) {
        return 0;
    }

    function _deposit(address, uint256) internal virtual {
        return;
    }

    function _withdraw(address, uint256) internal virtual {
        return;
    }

    function pause() external onlyOwnerOrKeeper {
        _pause();
    }

    function unpause() external onlyOwnerOrKeeper {
        _unpause();
    }

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

    function emergencyWithdraw() external onlyOwnerOrKeeper {
        _pause();
        uint256 assets = totalAssets();
        _emergencyWithdraw(assets);
    }

    function emergencyWithdraw(uint256 assets) external onlyOwnerOrKeeper {
        _pause();
        _emergencyWithdraw(assets);
    }

    function _emergencyWithdraw(uint256 assets) internal {
        _withdraw(address(this), assets);
    }

    function execute(address _to, uint256 _value, bytes calldata _data)
        external
        onlyOwner
        returns (bool, bytes memory)
    {
        (bool success, bytes memory result) = _to.call{value: _value}(_data);
        return (success, result);
    }
}
