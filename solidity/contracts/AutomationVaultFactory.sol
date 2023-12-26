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
  function automationVaults(uint256 _startFrom, uint256 _amount) external view returns (address[] memory _list) {
    uint256 _totalVaults = _automationVaults.length();

    // If amount is greater than the total vaults less the start index, set the amount to the difference
    if (_amount > _totalVaults - _startFrom) {
      _amount = _totalVaults - _startFrom;
    }

    // Initialize the paginated vaults array
    _list = new address[](_amount);

    uint256 _index;

    // Iterate over the vaults to get the paginated vaults
    while (_index < _amount) {
      _list[_index] = _automationVaults.at(_startFrom + _index);

      unchecked {
        ++_index;
      }
    }

    return _list;
  }

  /// @inheritdoc IAutomationVaultFactory
  function deployAutomationVault(
    address _owner,
    address _nativeToken,
    uint256 _salt
  ) external returns (IAutomationVault _automationVault) {
    // Create the new automation vault with the owner
    _automationVault = new AutomationVault{salt: keccak256(abi.encodePacked(msg.sender, _salt))}(_owner, _nativeToken);

    // Add the automation vault to the list of automation vaults
    _automationVaults.add(address(_automationVault));

    // Emit the event
    emit DeployAutomationVault(_owner, address(_automationVault));
  }
}
