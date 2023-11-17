# ⚠️ Might change in the future

1. The \_processReward function in AaveVault.sol will swap the reward token for the asset token,
   However, we haven't yet decided which DEX to use. We may need to change the code in the future.

2. If AAVE modifies its code upon its launch on Scroll, we may also need to adjust the related code within AaveVault.sol.

# Lazyotter Smart Contract

This repository contains the smart contracts source code for Lazyotter. The repository uses Foundry as development environment for compilation, testing and deployment tasks.

## What is Lazyotter?

LazyOtter serves as a trusted risk intelligence layer between users and projects, aiming to provide a safer DeFi investment alternative. Through meticulous risk identification and proactive mitigation strategies, it not only informs but also actively protects users from potential threats, enabling confident and secure navigation through the DeFi landscape.

## Documentation

See the link to the Lazyotter Developer docs

- [Developer Documentation](https://lazyotter.gitbook.io/lazyotter/developers/overview)

## Connect with the community

You can join the [Discord](https://discord.gg/mpkrs5EdgN) channel or [Telegram](https://t.me/+J4z2Jpb4HWQ2YjI1) group to ask questions about the protocol or talk about Lazyotter with other peers.

## Setup

Follow the next steps to setup the repository:

- Install `Foundry` and run `forge install`
- Create a `.env` file following the `.env.example` file

## Testing

```bash
forge test -w -vvv
```

## Coverage rate

make sure you install lcov on your mac

```bash
brew install lcov
```

generate test coverage report

```bash
forge coverage --report summary
genhtml -o coverage/result lcov.info
```

## Format

```bash
forge fmt
```

## VScode setting

Setting -> Solidity Formatter -> forge

## Deploy to localhost

```bash
anvil --balance 1000000000 --fork-url https://sepolia-rpc.scroll.io/ --chain-id {chainId} --fork-block-number {latestBlockNumber}
```

## Deploy vault to testnet

```bash
source .env
forge script script/scroll/DeployAaveUSDCVault.s.sol --rpc-url $SCROLL_TESTNET_RPC_URL --broadcast --legacy
```

## Verify vault

```bash
forge verify-contract {contractAddress} src/vaults/AaveVault.sol:AaveVault --chain-id 534351 --verifier-url https://sepolia-blockscout.scroll.io/api? --verifier blockscout
```

## Initialize vault

```bash
forge script script/local/InitializeAaveUSDCE.s.sol:Initialize --rpc-url http://127.0.0.1:8545 --legacy --broadcast
```

### cast

```
cast age --rpc-url http://127.0.0.1:8545 --block latest
cast block --rpc-url http://127.0.0.1:8545 latest
cast rpc --rpc-url 'http://localhost:8545' evm_increaseTime '86400'
cast rpc --rpc-url 'http://localhost:8545' evm_mine
```
