// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Script.sol";
import {ScrollMainnet} from "../../config/AddressBook.sol";

import {ICrocSwapDex} from "../../src/interfaces/ambient/ICrocSwapDex.sol";
import {ICrocQuery} from "../../src/interfaces/ambient/ICrocQuery.sol";
import {AmbientVaultHelper} from "../../src/helper/AmbientVaultHelper.sol";

contract Deploy is Script {
    ICrocSwapDex crocSwapDex = ICrocSwapDex(ScrollMainnet.AMBIENT_SWAPDEX);
    ICrocQuery crocQuery = ICrocQuery(ScrollMainnet.AMBIENT_QUERY);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        AmbientVaultHelper ambientVaultHelper = new AmbientVaultHelper(crocSwapDex, crocQuery);

        vm.stopBroadcast();

        console2.log("SCROLL_SYNCSWAP_USDC_WETH_VAULT=%s", address(ambientVaultHelper));
    }
}
