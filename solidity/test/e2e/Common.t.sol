// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {Deploy} from '@script/Deploy.s.sol';

contract DeployForTest is Deploy {
  uint256 private constant _FORK_BLOCK = 18_000_000;

  function setUp() public virtual {
    // Mainnet fork
    vm.createSelectFork('mainnet', _FORK_BLOCK);

    // Deployer setup
    _deployerPk = vm.deriveKey('test test test test test test test test test test test junk', 0);

    // AutomationVault setup
    owner = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    organizationName = 'TestOrg';
  }
}

abstract contract CommonE2ETest is DeployForTest, Test {
  function setUp() public virtual override {
    DeployForTest.setUp();

    run();
  }
}
