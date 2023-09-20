// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {IKeep3rRelay, Keep3rRelay, IAutomationVault} from '@contracts/Keep3rRelay.sol';

/**
 * @title Keep3rRelay Unit tests
 */
contract Keep3rRelayUnitTest is Test {
  using stdStorage for StdStorage;

  // Events tested
  event AutomationVaultExecuted(
    address indexed _automationVault, address indexed _relayCaller, IAutomationVault.ExecData[] _execData
  );

  // The target contract
  Keep3rRelay public keep3rRelay;

  function setUp() public virtual {
    keep3rRelay = new Keep3rRelay();
  }
}

contract UnitKeep3rRelayExec is Keep3rRelayUnitTest {
  modifier happyPath(address _relayCaller, address _automationVault, IAutomationVault.ExecData[] memory _execData) {
    assumeNoPrecompiles(_automationVault);
    vm.assume(_automationVault != address(vm));

    vm.mockCall(
      address(_automationVault),
      abi.encodeWithSelector(IAutomationVault.exec.selector, _relayCaller, _execData, new IAutomationVault.FeeData[](0)),
      abi.encode()
    );

    vm.startPrank(_relayCaller);
    _;
  }

  function testExpectCallWithCorrectsParams(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_relayCaller, _automationVault, _execData) {
    vm.expectCall(
      address(_automationVault),
      abi.encodeWithSelector(IAutomationVault.exec.selector, _relayCaller, _execData, new IAutomationVault.FeeData[](0))
    );

    keep3rRelay.exec(_automationVault, _execData);
  }

  function testEmitJobExecuted(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_relayCaller, _automationVault, _execData) {
    vm.expectEmit();
    emit AutomationVaultExecuted(_automationVault, _relayCaller, _execData);

    keep3rRelay.exec(_automationVault, _execData);
  }
}
