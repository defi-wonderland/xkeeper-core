// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

interface IXKeeperMetadata {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the description of an automation vault is set
   * @param  _automationVault The automation vault
   * @param  _description The description of the automation vault
   */
  event AutomationVaultMetadataSetted(IAutomationVault indexed _automationVault, string _description);

  /*///////////////////////////////////////////////////////////////
                          ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The caller is not the owner of the automation vault
   */
  error XKeeperMetadata_OnlyAutomationVaultOwner();

  /*///////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the description of the automation vault
   * @param  _automationVault The automation vault
   * @return _description The description of the automation vault
   */
  function automationVaultMetadata(IAutomationVault _automationVault)
    external
    view
    returns (string calldata _description);

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Sets the description of the automation vault
   * @param  _automationVault The automation vault
   * @param  _description The description of the automation vault
   */
  function setAutomationVaultMetadata(IAutomationVault _automationVault, string calldata _description) external;
}
