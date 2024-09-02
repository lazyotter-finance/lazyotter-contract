// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// It's ok to not use ERC20Upgradeable here
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICrocSwapDex} from "../../interfaces/ambient/ICrocSwapDex.sol";
import {ICrocLpConduit} from "../../interfaces/ambient/ICrocLpConduit.sol";

import {Vault} from "./Vault.sol";

import "forge-std/console.sol";

contract AmbientVault is Vault {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:aaveVaultStorage
    struct AmbientVaultStorage {
        // if the pair is ETH/USDC, baseToken is ETH, quoteToken is USDC
        address baseToken;
        address quoteToken;
    }

    // keccak256(abi.encode(uint256(keccak256("aaveVaultStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AmbientVaultStorageLocation =
        0x1543609c7215d70dab835e07add09594386b5e07f744a59e8ae128e3db8a8e00;

    function _getAmbientVaultStorage() private pure returns (AmbientVaultStorage storage $) {
        assembly {
            $.slot := AmbientVaultStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address keeper_
    ) public override initializer {
        super.initialize(asset_, name_, symbol_, keeper_);

        AmbientVaultStorage storage $ = _getAmbientVaultStorage();
        $.baseToken = ICrocLpConduit(address(asset_)).baseToken();
        $.quoteToken = ICrocLpConduit(address(asset_)).quoteToken();
    }

    function baseToken() public view returns (address) {
        return _getAmbientVaultStorage().baseToken;
    }

    function quoteToken() public view returns (address) {
        return _getAmbientVaultStorage().quoteToken;
    }
}
