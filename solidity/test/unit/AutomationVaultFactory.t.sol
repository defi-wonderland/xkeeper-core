// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {AutomationVaultFactory, EnumerableSet} from '@contracts/AutomationVaultFactory.sol';
import {AutomationVault} from '@contracts/AutomationVault.sol';

contract AutomationVaultFactoryForTest is AutomationVaultFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  function addAutomationVaultForTest(address[] memory _automationVaultsForTest) public {
    for (uint256 _index; _index < _automationVaultsForTest.length; _index++) {
      _automationVaults.add(_automationVaultsForTest[_index]);
    }
  }
}

/**
 * @title AutomationVaultFactory Unit tests
 */
abstract contract AutomationVaultFactoryUnitTest is Test {
  // Events
  event DeployAutomationVault(address indexed _owner, address indexed _automationVault);

  // AutomationVaultFactory contract
  AutomationVaultFactoryForTest public automationVaultFactory;

  // AutomationVault contract
  AutomationVault public automationVault;

  function setUp() public virtual {
    automationVault = AutomationVault(payable(0x104fBc016F4bb334D775a19E8A6510109AC63E00));

    automationVaultFactory = new AutomationVaultFactoryForTest();
  }
}

contract UnitAutomationVaultFactoryGetTotalAutomationVaults is AutomationVaultFactoryUnitTest {
  using EnumerableSet for EnumerableSet.AddressSet;

  // This is needed because foundry fuzz some values which are repeated
  EnumerableSet.AddressSet internal _cleanAutomationVaults;

  modifier happyPath(address[] memory _automationVaults) {
    vm.assume(_automationVaults.length > 0 && _automationVaults.length < 30);

    automationVaultFactory.addAutomationVaultForTest(_automationVaults);
    _;
  }

  function testGetTotalAutomationVaults(address[] memory _automationVaults) public happyPath(_automationVaults) {
    for (uint256 _index; _index < _automationVaults.length; _index++) {
      _cleanAutomationVaults.add(_automationVaults[_index]);
    }
    assertEq(automationVaultFactory.totalAutomationVaults(), _cleanAutomationVaults.length());
  }
}

contract UnitAutomationVaultFactoryGetAutomationVaults is AutomationVaultFactoryUnitTest {
  modifier happyPath(address[] memory _automationVaults, uint256 _startFrom, uint256 _amount) {
    // Avoid underflow
    vm.assume(_startFrom < _automationVaults.length);
    vm.assume(_amount < _automationVaults.length - _startFrom);

    automationVaultFactory.addAutomationVaultForTest(_automationVaults);
    _;
  }

  function testGetAutomationVaults(
    address[] memory _automationVaults,
    uint256 _startFrom,
    uint256 _automationVaultAmount
  ) public happyPath(_automationVaults, _startFrom, _automationVaultAmount) {
    address[] memory __automationVaults = automationVaultFactory.automationVaults(_startFrom, _automationVaultAmount);

    assertEq(__automationVaults.length, _automationVaultAmount);
  }
}

contract UnitAutomationVaultFactoryDeployAutomationVault is AutomationVaultFactoryUnitTest {
  function testDeployAutomationVault(address _owner) public {
    automationVaultFactory.deployAutomationVault(_owner);

    assertEq(address(automationVault).code, type(AutomationVault).runtimeCode);

    // params
    assertEq(automationVault.owner(), _owner);
  }

  function testSetAutomationVaults(address _owner) public {
    automationVaultFactory.deployAutomationVault(_owner);

    assertEq(automationVaultFactory.automationVaults(0, 1)[0], address(automationVault));
  }

  function testEmitDeployAutomationVault(address _owner) public {
    vm.expectEmit();
    emit DeployAutomationVault(_owner, address(automationVault));

    automationVaultFactory.deployAutomationVault(_owner);
  }

  function testReturnAutomationVault(address _owner) public {
    assertEq(address(automationVaultFactory.deployAutomationVault(_owner)), address(automationVault));
  }
}
