// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {IGelatoRelay, GelatoRelay, IAutomationVault} from '@contracts/GelatoRelay.sol';

/**
 * @title GelatoRelay Unit tests
 */
contract GelatoRelayUnitTest is Test {
  using stdStorage for StdStorage;

  // Events tested
  event AutomationVaultExecuted(
    address indexed _relayCaller, IAutomationVault.ExecData[] _execData, IAutomationVault.FeeData[] _feeData
  );

  // The target contract
  GelatoRelay public gelatoRelay;

  function setUp() public virtual {
    gelatoRelay = new GelatoRelay();
  }
}

contract UnitGelatoRelayExec is GelatoRelayUnitTest {
  modifier happyPath(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) {
    vm.etch(address(_automationVault), hex'069420');

    vm.mockCall(
      address(_automationVault),
      abi.encodeWithSelector(IAutomationVault.exec.selector, _relayCaller, _execData, _feeData),
      abi.encode()
    );

    vm.startPrank(_relayCaller);
    _;
  }

  function testExpectCallWithCorrectsParams(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relayCaller, _automationVault, _execData, _feeData) {
    vm.expectCall(
      address(_automationVault),
      abi.encodeWithSelector(IAutomationVault.exec.selector, _relayCaller, _execData, _feeData)
    );

    gelatoRelay.exec(_automationVault, _execData, _feeData);
  }

  function testEmitJobExecuted(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relayCaller, _automationVault, _execData, _feeData) {
    vm.expectEmit();
    emit AutomationVaultExecuted(_relayCaller, _execData, _feeData);

    gelatoRelay.exec(address(_automationVault), _execData, _feeData);
  }
}
