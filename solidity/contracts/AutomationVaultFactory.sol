// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVaultFactory} from '@interfaces/IAutomationVaultFactory.sol';
import {AutomationVault, IAutomationVault} from '@contracts/AutomationVault.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

/**
 * @title  AutomationVaultFactory
 * @notice This contract deploys the new automation vaults
 */
contract AutomationVaultFactory is IAutomationVaultFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  /**
   * @notice List of deployed automation vaults
   */
  EnumerableSet.AddressSet internal _automationVaults;

  /// @inheritdoc IAutomationVaultFactory
  function totalAutomationVaults() external view returns (uint256 _totalAutomationVaults) {
    _totalAutomationVaults = _automationVaults.length();
  }

  /// @inheritdoc IAutomationVaultFactory
  function automationVaults(
    uint256 _startFrom,
    uint256 _automationVaultAmount
  ) external view returns (address[] memory __automationVaults) {
    uint256 _totalVaults = _automationVaults.length();

    // If amount is greater than the total vaults less the start index, set the amount to the difference
    if (_automationVaultAmount > _totalVaults - _startFrom) {
      _automationVaultAmount = _totalVaults - _startFrom;
    }

    // Initialize the paginated vaults array
    __automationVaults = new address[](_automationVaultAmount);

    uint256 _index;

    // Iterate over the vaults to get the paginated vaults
    while (_index < _automationVaultAmount) {
      __automationVaults[_index] = _automationVaults.at(_startFrom + _index);

      unchecked {
        ++_index;
      }
    }

    return __automationVaults;
  }

  /// @inheritdoc IAutomationVaultFactory
  function deployAutomationVault(
    address _owner,
    string calldata _organizationName
  ) external returns (IAutomationVault _automationVault) {
    // Create the new automation vault for the owner with the organization name
    _automationVault = new AutomationVault(_owner, _organizationName);

    // Add the automation vault to the list of automation vaults
    _automationVaults.add(address(_automationVault));

    // Emit the event
    emit DeployAutomationVault(_owner, _organizationName, address(_automationVault));
  }
}
