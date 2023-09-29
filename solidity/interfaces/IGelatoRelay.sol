// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

interface IGelatoRelay {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when an automation vault is executed
   * @param  _automationVault The address of the automation vault
   * @param  _relayCaller The address of the relay caller
   * @param  _execData The array of exec data
   * @param  _feeData The array of fee data
   */
  event AutomationVaultExecuted(
    address indexed _automationVault,
    address indexed _relayCaller,
    IAutomationVault.ExecData[] _execData,
    IAutomationVault.FeeData[] _feeData
  );

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Execute an automation vault which will execute the jobs and will manage the payment to the fee data receivers
   * @param  _automationVault The address of the automation vault
   * @param  _execData The array of exec data
   * @param  _feeData The array of fee data
   */
  function exec(
    address _automationVault,
    IAutomationVault.ExecData[] calldata _execData,
    IAutomationVault.FeeData[] calldata _feeData
  ) external;
}
