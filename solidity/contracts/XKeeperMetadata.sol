// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IXKeeperMetadata} from '@interfaces/IXKeeperMetadata.sol';
import {IAutomationVault} from '@interfaces/IAutomationVault.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

/**
 * @title  XKeeperMetadata
 * @notice This contract is used for managing the metadata of automation vaults
 */

contract XKeeperMetadata is IXKeeperMetadata {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @inheritdoc IXKeeperMetadata
  mapping(IAutomationVault _automationVault => IXKeeperMetadata.AutomationVaultMetadata _automationVaultMetadata) public
    automationVaultMetadata;

  /**
   * @notice List of automationVaults that have metadata
   */
  EnumerableSet.AddressSet internal _automationVaults;

  /// @inheritdoc IXKeeperMetadata
  function automationVaults() external view returns (address[] memory __automationVaults) {
    __automationVaults = _automationVaults.values();
  }

  /// @inheritdoc IXKeeperMetadata
  function automationVaultsMetadata(IAutomationVault[] calldata _automationVault)
    external
    view
    returns (IXKeeperMetadata.AutomationVaultMetadata[] memory _metadata)
  {
    // Initialize the array
    _metadata = new IXKeeperMetadata.AutomationVaultMetadata[](_automationVault.length);

    // Iterate over the automation vaults and get the metadata
    for (uint256 _i; _i < _automationVault.length;) {
      _metadata[_i] = automationVaultMetadata[_automationVault[_i]];

      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IXKeeperMetadata
  function setAutomationVaultMetadata(
    IAutomationVault _automationVault,
    IXKeeperMetadata.AutomationVaultMetadata calldata _automationVaultMetadata
  ) external {
    // Check if the caller is the owner of the automation vault
    if (_automationVault.owner() != msg.sender) {
      revert XKeeperMetadata_OnlyAutomationVaultOwner();
    }

    // Add the automation vault to the list of automation vaults and set the metadata
    automationVaultMetadata[_automationVault] = _automationVaultMetadata;
    _automationVaults.add(address(_automationVault));

    emit AutomationVaultMetadataSetted(
      _automationVault, _automationVaultMetadata.name, _automationVaultMetadata.description
    );
  }
}
