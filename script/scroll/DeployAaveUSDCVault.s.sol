// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Script.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IRewardsController} from "../../src/interfaces/aave/IRewardsController.sol";
import {IDataProvider} from "../../src/interfaces/aave/IDataProvider.sol";
import {ILendingPool} from "../../src/interfaces/aave/ILendingPool.sol";

import {AaveVault} from "../../src/vaults/AaveVault.sol";
import {Vault} from "../../src/vaults/Vault.sol";

contract Deploy is Script {
    // TODO: set treasury, keeper addresses
    address treasury = vm.envAddress("ARBITRUM_TREASURY");
    address keeper = vm.envAddress("ARBITRUM_KEEPER");

    IERC20 USDC = IERC20(vm.envAddress("SCROLL_TESTNET_USDC"));
    IERC20 WETH = IERC20(vm.envAddress("SCROLL_TESTNET_WETH"));

    IDataProvider dataProvider = IDataProvider(vm.envAddress("SCROLL_TESTNET_AAVE_DATAPROVIDER"));
    ILendingPool lendingPool = ILendingPool(vm.envAddress("SCROLL_TESTNET_AAVE_LENDINGPOOL"));
    IRewardsController rewardsController = IRewardsController(vm.envAddress("SCROLL_TESTNET_AAVE_REWARDSCONTROLLER"));

    ISwapRouter public swapRouter = ISwapRouter(vm.envAddress("SCROLL_TESTNET_UNISWAP_SWAPROUTER"));
    IUniswapV3Factory public factory = IUniswapV3Factory(vm.envAddress("SCROLL_TESTNET_UNISWAP_FACTORY"));

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address[] memory recipients = new address[](1);
        recipients[0] = treasury;

        uint256[] memory recipientWeights = new uint256[](1);
        recipientWeights[0] = 500;

        Vault.FeeInfo memory feeInfo = Vault.FeeInfo(recipients, recipientWeights, 200, 0, 0);

        vm.startBroadcast(deployerPrivateKey);

        AaveVault aaveVault = new AaveVault(
            USDC,
            "LazyOtter: Vault AAVE USDC",
            "LOT",
            feeInfo,
            keeper,
            dataProvider,
            lendingPool,
            rewardsController,
            swapRouter,
            factory,
            WETH
        );

        vm.stopBroadcast();

        console2.log("SCROLL_TESTNET_AAVE_USDC_VAULT=%s", address(aaveVault));
    }
}
