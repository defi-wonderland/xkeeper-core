// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IXKeeperMetadata} from '@interfaces/IXKeeperMetadata.sol';
import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

/**
 * @title  XKeeperMetadata
 * @notice This contract is used for managing the metadata of automation vaults
 */

contract XKeeperMetadata is IXKeeperMetadata {
  /// @inheritdoc IXKeeperMetadata
  mapping(IAutomationVault _automationVault => IXKeeperMetadata.AutomationVaultMetadata _automationVaultMetadata) public
    automationVaultMetadata;

  /// @inheritdoc IXKeeperMetadata
  function setAutomationVaultMetadata(
    IAutomationVault _automationVault,
    IXKeeperMetadata.AutomationVaultMetadata calldata _automationVaultMetadata
  ) external {
    // Check if the caller is the owner of the automation vault
    if (_automationVault.owner() != msg.sender) {
      revert XKeeperMetadata_OnlyAutomationVaultOwner();
    }

    automationVaultMetadata[_automationVault] = _automationVaultMetadata;
    emit AutomationVaultMetadataSetted(
      _automationVault, _automationVaultMetadata.name, _automationVaultMetadata.description
    );
  }
}
