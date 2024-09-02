// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";

import "forge-std/console.sol";

contract Vault is
    Initializable,
    ERC4626Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    uint256 public constant MAX_FEE_RATE = 10000;
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    /* If we want to add variable to this contract, we can add it here.*/
    // /// @custom:storage-location erc7201:vaultUpgradableStorage
    // struct VaultUpgradableStorage {}

    // // keccak256(abi.encode(uint256(keccak256("vaultUpgradableStorage")) - 1)) & ~bytes32(uint256(0xff))
    // bytes32 private constant VaultUpgradableStorageLocation =
    //     0x79dd70473dc267dc20d8f408d834000dc27a72094a8fd59bbb6d0bc83c8cdb00;

    // function _getVaultUpgradableStorage() private pure returns (VaultUpgradableStorage storage $) {
    //     assembly {
    //         $.slot := VaultUpgradableStorageLocation
    //     }
    // }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address keeper_
    ) public virtual initializer {
        __ERC4626_init(asset_);
        __ERC20_init(name_, symbol_);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        // set role
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(KEEPER_ROLE, DEFAULT_ADMIN_ROLE);
        _grantRole(KEEPER_ROLE, keeper_);
    }

    modifier onlyOwner() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    modifier onlyOwnerOrKeeper() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(KEEPER_ROLE, msg.sender), "Permissions denied");
        _;
    }

    function deposit(uint256 assets, address receiver) public override nonReentrant whenNotPaused returns (uint256) {
        uint256 shares = super.deposit(assets, receiver);
        return shares;
    }

    function mint(uint256 shares, address receiver) public override nonReentrant whenNotPaused returns (uint256) {
        uint256 assets = super.mint(shares, receiver);
        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) public override nonReentrant returns (uint256) {
        uint256 shares = super.withdraw(assets, receiver, owner);
        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public override nonReentrant returns (uint256) {
        uint256 assets = super.redeem(shares, receiver, owner);
        return assets;
    }

    // Pause and unpause functions
    function pause() external onlyOwnerOrKeeper {
        _pause();
    }

    function unpause() external onlyOwnerOrKeeper {
        _unpause();
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

    function _decimalsOffset() internal pure override returns (uint8) {
        return 6;
    }

    // Override the _deposit function to add custom logic, will implement fee structure in the future version
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        super._deposit(caller, receiver, assets, shares);

        _deposit_(receiver, assets);
    }

    // Override the _withdraw function to add custom logic, will implement fee structure in the future version
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        _withdraw_(owner, assets);

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    // Custom logic for deposit to different protocol, child contract could override it
    function _deposit_(address receiver, uint256 assets) internal virtual {
        // add custom logic here
    }

    // Custom logic for withdraw from different protocol, child contract could override it
    function _withdraw_(address owner, uint256 assets) internal virtual {
        // add custom logic here
    }

    function _emergencyWithdraw(uint256 assets) internal {
        _withdraw_(address(this), assets);
    }

    function execute(
        address to_,
        uint256 value_,
        bytes calldata data_
    ) external onlyOwner returns (bool, bytes memory) {
        (bool success, bytes memory result) = to_.call{value: value_}(data_);
        return (success, result);
    }
}
