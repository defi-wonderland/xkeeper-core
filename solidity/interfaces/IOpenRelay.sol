// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

interface IOpenRelay {
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
                              ERRORS  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the exec data is empty
   */
  error OpenRelay_NoExecData();

  /*///////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the gas bonus
   * @return _gasBonus The value of the gas bonus
   */
  function GAS_BONUS() external view returns (uint256 _gasBonus);

  /**
   * @notice Returns the gas multiplier
   * @return _gasMultiplier The value of the gas multiplier
   */
  function GAS_MULTIPLIER() external view returns (uint256 _gasMultiplier);

  /**
   * @notice Returns the base used for the payment calculation
   * @return _base The value of the base
   */
  function BASE() external view returns (uint32 _base);

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Execute an automation vault which will execute the jobs and will manage the payment to the fee data receivers
   * @dev    The payment will be calculated on the basis of several variables like the gas spent, the base fee,
   *         the gas bonus and the gas multiplier
   * @param  _automationVault The automation vault that will be executed
   * @param  _execData The array of exec data
   * @param  _feeRecipient The address of the fee recipient
   */
  function exec(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] calldata _execData,
    address _feeRecipient
  ) external;
}
