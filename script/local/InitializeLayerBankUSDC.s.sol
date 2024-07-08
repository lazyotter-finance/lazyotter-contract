// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "forge-std/Script.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import {IWETH} from "../../src/interfaces/lazyotter/IWETH.sol";
import {UniswapHelper} from "../../src/helper/UniswapHelper.sol";
import {LayerBankVault} from "../../src/vaults/LayerBankVault.sol";

import {ScrollMainnet} from "../../config/AddressBook.sol";

contract Initialize is Script {
    address owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    IERC20 USDC = IERC20(ScrollMainnet.USDC);
    IWETH WETH = IWETH(ScrollMainnet.WETH);

    ISwapRouter public swapRouter =
        ISwapRouter(ScrollMainnet.UNISWAP_SWAPROUTER);

    LayerBankVault public layerBankUSDCVault =
        LayerBankVault(vm.envAddress("SCROLL_LAYERBANK_USDC_VAULT"));

    function run() external {
        uint256 WETHAmount = 15 ether;
        uint256 amount = 3000 * 1e6;
        uint24 fee = 5000;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        WETH.deposit{value: WETHAmount}();

        WETH.approve(address(swapRouter), WETHAmount + 1 ether);

        TransferHelper.safeApprove(
            address(WETH),
            address(swapRouter),
            WETHAmount
        );

        ISwapRouter.ExactOutputParams memory params = ISwapRouter
            .ExactOutputParams({
                path: abi.encodePacked(USDC, fee, WETH),
                recipient: owner,
                deadline: block.timestamp + 1 minutes,
                amountOut: amount,
                amountInMaximum: WETHAmount
            });

        // swap
        // TODO: [Revert] EvmError: Revert
        swapRouter.exactOutput(params);

        // deposit
        uint256 depositAmount = USDC.balanceOf(owner) / 2;
        USDC.approve(address(layerBankUSDCVault), depositAmount);
        layerBankUSDCVault.deposit(depositAmount, owner);

        vm.stopBroadcast();
    }
}
