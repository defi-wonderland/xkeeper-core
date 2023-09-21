// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {GelatoRelay, IAutomationVault} from '@contracts/GelatoRelay.sol';

/**
 * @title GelatoRelay Unit tests
 */
contract GelatoRelayUnitTest is Test {
  // Events
  event AutomationVaultExecuted(
    address indexed _automationVault,
    address indexed _relayCaller,
    IAutomationVault.ExecData[] _execData,
    IAutomationVault.FeeData[] _feeData
  );

  // GelatoRelay contract
  GelatoRelay public gelatoRelay;

  function setUp() public virtual {
    gelatoRelay = new GelatoRelay();
  }
}

contract UnitGelatoRelayExec is GelatoRelayUnitTest {
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
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relayCaller, _automationVault) {
    vm.expectCall(
      _automationVault, abi.encodeWithSelector(IAutomationVault.exec.selector, _relayCaller, _execData, _feeData)
    );

    gelatoRelay.exec(_automationVault, _execData, _feeData);
  }

  function testEmitJobExecuted(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relayCaller, _automationVault) {
    vm.expectEmit();
    emit AutomationVaultExecuted(_automationVault, _relayCaller, _execData, _feeData);

    gelatoRelay.exec(_automationVault, _execData, _feeData);
  }
}
