// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/core/IAutomationVault.sol';
import {IBasicJob} from '@interfaces/for-test/IBasicJob.sol';

interface IBasicJobChecker {
  /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice This function checks whether the job can be executed by the automation vault
   * @param _automationVault The automation vault that will execute the job
   * @param _basicJob The basic job that will be executed
   * @return _canExec Whether the job can be executed
   * @return _execPayload The payload that will be executed by the automation vault
   */
  function checker(
    IAutomationVault _automationVault,
    IBasicJob _basicJob
  ) external pure returns (bool _canExec, bytes memory _execPayload);
}
