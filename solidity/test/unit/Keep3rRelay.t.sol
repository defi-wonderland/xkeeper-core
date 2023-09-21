// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {Keep3rRelay, IAutomationVault} from '@contracts/Keep3rRelay.sol';

/**
 * @title Keep3rRelay Unit tests
 */
contract Keep3rRelayUnitTest is Test {
  // Events
  event AutomationVaultExecuted(
    address indexed _automationVault, address indexed _relayCaller, IAutomationVault.ExecData[] _execData
  );

  // Keep3rRelay contract
  Keep3rRelay public keep3rRelay;

  function setUp() public virtual {
    keep3rRelay = new Keep3rRelay();
  }
}

contract UnitKeep3rRelayExec is Keep3rRelayUnitTest {
  modifier happyPath(address _relayCaller, address _automationVault) {
    assumeNoPrecompiles(_automationVault);
    vm.assume(_automationVault != address(vm));
    vm.mockCall(_automationVault, abi.encodeWithSelector(IAutomationVault.exec.selector), abi.encode());

    vm.startPrank(_relayCaller);
    _;
  }

  function testExpectCallWithCorrectsParams(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_relayCaller, _automationVault) {
    vm.expectCall(
      _automationVault,
      abi.encodeWithSelector(IAutomationVault.exec.selector, _relayCaller, _execData, new IAutomationVault.FeeData[](0))
    );

    keep3rRelay.exec(_automationVault, _execData);
  }

  function testEmitJobExecuted(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_relayCaller, _automationVault) {
    vm.expectEmit();
    emit AutomationVaultExecuted(_automationVault, _relayCaller, _execData);

    keep3rRelay.exec(_automationVault, _execData);
  }
}
