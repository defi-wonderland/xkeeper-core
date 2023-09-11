// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVaultFactory} from '@interfaces/IAutomationVaultFactory.sol';
import {AutomationVault, IAutomationVault} from '@contracts/AutomationVault.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract AutomationVaultFactory is IAutomationVaultFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _automationVaults;

  /// @inheritdoc IAutomationVaultFactory
  function automationVaults() external view returns (address[] memory __automationVaults) {
    return _automationVaults.values();
  }

  /// @inheritdoc IAutomationVaultFactory
  function deployAutomationVault(
    address _owner,
    string calldata _organizationName
  ) external returns (IAutomationVault _automationVault) {
    _automationVault = new AutomationVault(_owner, _organizationName);
    _automationVaults.add(address(_automationVault));
    emit DeployAutomationVault(_owner, _organizationName, address(_automationVault));
  }
}
