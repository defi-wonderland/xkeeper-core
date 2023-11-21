// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IXKeeperMetadata} from '@interfaces/IXKeeperMetadata.sol';
import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

/**
 * @title  XKeeperMetadata
 * @notice This contract is used for managing the metadata of automation vaults
 */

contract XKeeperMetadata is IXKeeperMetadata {
  /// @inheritdoc IXKeeperMetadata
  mapping(IAutomationVault _automationVault => string _description) public automationVaultMetadata;

  /// @inheritdoc IXKeeperMetadata
  function setAutomationVaultMetadata(IAutomationVault _automationVault, string calldata _description) external {
    // Check if the caller is the owner of the automation vault
    if (_automationVault.owner() != msg.sender) {
      revert XKeeperMetadata_OnlyAutomationVaultOwner();
    }

    automationVaultMetadata[_automationVault] = _description;
    emit AutomationVaultMetadataSetted(_automationVault, _description);
  }
}
