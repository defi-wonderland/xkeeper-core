// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/core/IAutomationVault.sol';
import {IKeep3rV2} from '@interfaces/external/IKeep3rV2.sol';

interface IKeep3rRelay {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when an automation vault is executed
   * @param  _automationVault The address of the automation vault
   * @param  _relayCaller The address of the relay caller
   * @param  _execData The array of exec data
   */
  event AutomationVaultExecuted(
    IAutomationVault indexed _automationVault, address indexed _relayCaller, IAutomationVault.ExecData[] _execData
  );

  /*///////////////////////////////////////////////////////////////
                              ERRORS  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the exec data is empty
   */
  error Keep3rRelay_NoExecData();

  /**
   * @notice Thrown when the caller is not a keeper
   */
  error Keep3rRelay_NotKeeper();

  /**
   * @notice Thrown when the exec data contains Keep3r V2
   */
  error Keep3rRelay_Keep3rNotAllowed();

  /*///////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Get the keep3rV2 contract
   * @return _keep3rV2 The keep3rV2 contract
   */
  function KEEP3R_V2() external view returns (IKeep3rV2 _keep3rV2);

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Execute an automation vault which will execute the jobs and will manage the payment to the fee data receivers
   * @dev    The payment will be managed by keep3r network. The first and last exec data are assembled by the relay in order to be able to work with keep3r network
   * @param  _automationVault The automation vault that will be executed
   * @param  _execData The array of exec data
   */
  function exec(IAutomationVault _automationVault, IAutomationVault.ExecData[] calldata _execData) external;
}
