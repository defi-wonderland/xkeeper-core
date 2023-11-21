// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {BasicJob} from '@contracts/for-test/BasicJob.sol';
import {Deploy} from '@script/Deploy.s.sol';

contract DeployForTest is Deploy {
  uint256 private constant _FORK_BLOCK = 18_000_000;

  function setUp() public virtual {
    // Mainnet fork
    vm.createSelectFork('mainnet', _FORK_BLOCK);

    // Deployer setup
    _deployerPk = vm.deriveKey('test test test test test test test test test test test junk', 0);

    // AutomationVault setup
    owner = makeAddr('Owner');
  }
}

abstract contract CommonIntegrationTest is DeployForTest, Test {
  // Events
  event Worked();

  // ForTest contracts
  BasicJob public basicJob;

  // EOAs
  address public bot;

  function setUp() public virtual override {
    DeployForTest.setUp();

    bot = makeAddr('Bot');

    basicJob = new BasicJob();

    run();
  }
}
