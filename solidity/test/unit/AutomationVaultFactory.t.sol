// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {AutomationVaultFactory} from '@contracts/AutomationVaultFactory.sol';
import {AutomationVault} from '@contracts/AutomationVault.sol';

/**
 * @title AutomationVaultFactory Unit tests
 */
abstract contract AutomationVaultFactoryUnitTest is Test {
  // Events
  event DeployAutomationVault(
    address indexed _owner, string indexed _organizationName, address indexed _automationVault
  );

  // AutomationVaultFactory contract
  AutomationVaultFactory public automationVaultFactory;

  // AutomationVault contract
  AutomationVault public automationVault;

  function setUp() public virtual {
    automationVault = AutomationVault(payable(0x104fBc016F4bb334D775a19E8A6510109AC63E00));

    automationVaultFactory = new AutomationVaultFactory();
  }
}

contract UnitAutomationVaultFactoryDeployAutomationVault is AutomationVaultFactoryUnitTest {
  function testDeployAutomationVault(address _owner, string calldata _organizationName) public {
    automationVaultFactory.deployAutomationVault(_owner, _organizationName);

    assertEq(address(automationVault).code, type(AutomationVault).runtimeCode);

    // params
    assertEq(automationVault.owner(), _owner);
    assertEq(automationVault.organizationName(), _organizationName);
  }

  function testSetAutomationVaults(address _owner, string calldata _organizationName) public {
    automationVaultFactory.deployAutomationVault(_owner, _organizationName);

    assertEq(automationVaultFactory.automationVaults()[0], address(automationVault));
  }

  function testEmitDeployAutomationVault(address _owner, string calldata _organizationName) public {
    vm.expectEmit();
    emit DeployAutomationVault(_owner, _organizationName, address(automationVault));

    automationVaultFactory.deployAutomationVault(_owner, _organizationName);
  }

  function testReturnAutomationVault(address _owner, string calldata _organizationName) public {
    assertEq(address(automationVaultFactory.deployAutomationVault(_owner, _organizationName)), address(automationVault));
  }
}
