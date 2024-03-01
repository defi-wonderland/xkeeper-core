// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IAutomate} from '@interfaces/external/IAutomate.sol';
import {IAutomationVault} from '@interfaces/core/IAutomationVault.sol';

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
    IAutomationVault indexed _automationVault,
    address indexed _relayCaller,
    IAutomationVault.ExecData[] _execData,
    IAutomationVault.FeeData[] _feeData
  );

  /*///////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the automate contract of the gelato network
   * @return _automate The address of the automate contract
   */
  function AUTOMATE() external view returns (IAutomate _automate);

  /**
   * @notice Returns the fee collector of the gelato network
   * @return _feeCollector The address of the fee collector
   */
  function FEE_COLLECTOR() external view returns (address _feeCollector);

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Execute an automation vault which will execute the jobs and will manage the payment to the fee data receivers
   * @param  _automationVault The automation vault that will be executed
   * @param  _execData The array of exec data
   */
  function exec(IAutomationVault _automationVault, IAutomationVault.ExecData[] calldata _execData) external;
}
