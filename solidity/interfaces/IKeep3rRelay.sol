// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

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
    address indexed _automationVault, address indexed _relayCaller, IAutomationVault.ExecData[] _execData
  );

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Execute an automation vault which will execute the jobs and will managed the payment to the fee data receivers
   * @dev    The payment will be manage by keep3r network
   * @param  _automationVault The address of the automation vault
   * @param  _execData The array of exec data
   */
  function exec(address _automationVault, IAutomationVault.ExecData[] calldata _execData) external;
}
