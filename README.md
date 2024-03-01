# xKeeper Core

[License: AGPL-3.0](https://github.com/defi-wonderland/xkeeper-core/blob/main/LICENSE)

⚠️ The code has not been audited yet, tread with caution.

## Overview

xKeeper is a keeper network aggregator which aims to decentralise the on-chain automation of DeFi. With xKeeper, using multiple keeper networks, such as Keep3r Network, Gelato, or others, will be a walk in the park.

xKeeper is a fully modular framework, designed to be the backbone of future onchain automation.

- App: [xkeeper.network](https://xkeeper.network/)
- Documentation: [docs.xkeeper.network](https://docs.xkeeper.network/)

## Setup

This project uses [Foundry](https://book.getfoundry.sh/). To build it locally, run:

```sh
git clone git@github.com:defi-wonderland/xkeeper-core.git
cd xkeeper-core
yarn install
yarn build
```

### Available Commands

Make sure to set `ETHEREUM_MAINNET_RPC` environment variable before running integration tests.

| Yarn Command            | Description                                                                                      |
| ----------------------- | ------------------------------------------------------------------------------------------------ |
| `yarn build`            | Compile all contracts.                                                                           |
| `yarn coverage`         | See `forge coverage` report.                                                                     |
| `yarn deploy:mainnet`   | Deploy the contracts to mainnet.                                                                 |
| `yarn deploy:goerli`    | Deploy the contracts to goerli testnet                                                           |
| `yarn docs:build`       | Generate documentation with [`forge doc`](https://book.getfoundry.sh/reference/forge/forge-doc). |
| `yarn docs:run`         | Start the documentation server.                                                                  |
| `yarn test`             | Run all unit and integration tests.                                                              |
| `yarn test:unit`        | Run unit tests.                                                                                  |
| `yarn test:integration` | Run integration tests.                                                                           |
| `yarn test:gas`         | Run all unit and integration tests, and make a gas report.                                       |

## Licensing

The primary license for xKeeper contracts is AGPL-3.0, see [`LICENSE`](./LICENSE).

## Contributors

xKeeper was built with ❤️ by [Wonderland](https://defi.sucks).

Wonderland is the largest core development group in web3. Our commitment is to a financial future that's open, decentralized, and accessible to all.

[DeFi sucks](https://defi.sucks), but Wonderland is here to make it better.
