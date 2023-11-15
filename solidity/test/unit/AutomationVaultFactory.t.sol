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
  event DeployAutomationVault(
    address indexed _owner, string indexed _organizationName, address indexed _automationVault
  );

  // AutomationVaultFactory contract
  AutomationVaultFactoryForTest public automationVaultFactory;

  // AutomationVault contract
  AutomationVault public automationVault;

  function setUp() public virtual {
    automationVault = AutomationVault(payable(0x104fBc016F4bb334D775a19E8A6510109AC63E00));

    automationVaultFactory = new AutomationVaultFactoryForTest();
  }
}

contract UnitAutomationVaultFactoryGetAutomationVaults is AutomationVaultFactoryUnitTest {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _enumerableAutomationVaults;

  modifier happyPath(address[] memory _automationVaults) {
    vm.assume(_automationVaults.length > 0 && _automationVaults.length < 30);
    automationVaultFactory.addAutomationVaultForTest(_automationVaults);
    _;
  }

  function testGetAutomationVaults(address[] memory _automationVaults) public happyPath(_automationVaults) {
    for (uint256 _index; _index < _automationVaults.length; _index++) {
      _enumerableAutomationVaults.add(_automationVaults[_index]);
    }
    assertEq(automationVaultFactory.automationVaults(), _enumerableAutomationVaults.values());
  }
}

contract UnitAutomationVaultFactoryGetPaginatedAutomationVaults is AutomationVaultFactoryUnitTest {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _enumerableAutomationVaults;

  modifier happyPath(address[] memory _automationVaults, uint256 _startFrom, uint256 _amount) {
    vm.assume(_automationVaults.length > 0 && _automationVaults.length < 30);

    // Avoid underflow
    vm.assume(_startFrom < _automationVaults.length);
    vm.assume(_amount < _automationVaults.length - _startFrom);

    automationVaultFactory.addAutomationVaultForTest(_automationVaults);
    _;
  }

  function testGetPaginatedAutomationVaults(
    address[] memory _automationVaults,
    uint256 _startFrom,
    uint256 _amount
  ) public happyPath(_automationVaults, _startFrom, _amount) {
    for (uint256 _index; _index < _automationVaults.length; _index++) {
      _enumerableAutomationVaults.add(_automationVaults[_index]);
    }

    address[] memory _paginatedAutomationVaults = automationVaultFactory.paginatedAutomationVaults(_startFrom, _amount);

    assertEq(_paginatedAutomationVaults.length, _amount);
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
