// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "forge-std/Script.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IWETH} from "../../src/interfaces/lazyotter/IWETH.sol";
import {UniswapHelper} from "../../src/helper/UniswapHelper.sol";
import {AaveVault} from "../../src/vaults/AaveVault.sol";
import {Vault} from "../../src/vaults/Vault.sol";

contract Initialize is Script {
    address owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    IERC20 USDCE = IERC20(vm.envAddress("ARBITRUM_USDCE"));
    IWETH WETH = IWETH(vm.envAddress("ARBITRUM_WETH"));

    ISwapRouter public swapRouter = ISwapRouter(vm.envAddress("ARBITRUM_UNISWAP_SWAPROUTER"));

    Vault public AaveUSDCEVault = Vault(vm.envAddress("ARBITRUM_AAVE_USDCE_VAULT"));

    function run() external {
        uint256 WETHAmount = 15 ether;
        uint256 amount = 2000 * 1e6;
        uint24 fee = 500;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        WETH.deposit{value: WETHAmount}();

        WETH.approve(address(swapRouter), WETHAmount + 1 ether);

        TransferHelper.safeApprove(address(WETH), address(swapRouter), WETHAmount);

        ISwapRouter.ExactOutputParams memory params = ISwapRouter.ExactOutputParams({
            path: abi.encodePacked(USDCE, fee, WETH),
            recipient: owner,
            deadline: block.timestamp + 1 minutes,
            amountOut: amount,
            amountInMaximum: WETHAmount
        });

        // swap
        swapRouter.exactOutput(params);

        // deposit
        uint256 depositAmount = USDCE.balanceOf(owner) / 2;
        USDCE.approve(address(AaveUSDCEVault), depositAmount);
        AaveUSDCEVault.deposit(depositAmount, owner);

        vm.stopBroadcast();
    }
}
