// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {CommonE2ETest} from '@test/e2e/Common.t.sol';

contract E2EDeploy is CommonE2ETest {
  function test_AutomationVault_Params() public {
    assertEq(automationVault.owner(), owner);
    assertEq(automationVault.organizationName(), organizationName);
  }
}
