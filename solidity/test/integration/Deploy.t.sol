// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {CommonIntegrationTest} from '@test/integration/Common.t.sol';

contract IntegrationDeploy is CommonIntegrationTest {
  function test_automation_vault_params() public {
    assertEq(automationVault.owner(), owner);
    assertEq(automationVault.organizationName(), organizationName);
  }
}