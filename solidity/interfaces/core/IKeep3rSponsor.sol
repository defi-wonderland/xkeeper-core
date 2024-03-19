// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/relays/IOpenRelay.sol';

interface IKeep3rSponsor {
  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not a valid keeper
   */
  error Keep3rSponsor_NotKeeper();

  /**
   * @notice Thrown when the job executed is not in the list of sponsored jobs
   */
  error Keep3rSponsor_NotSponsored();

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Sets the relay to forward calls to
   * @param  _relay Address of relay to set
   */
  function setRelay(address _relay) external;

  /**
   * @notice Adds a job to the sponsored list
   * @param  _jobs List of jobs to add
   */
  function addJobs(address[] calldata _jobs) external;

  /**
   * @notice Removes a job from the sponsored list
   * @param  _jobs List of jobs to remove
   */
  function removeJobs(address[] calldata _jobs) external;

  /**
   * @notice Executes a job by forwarding it to the correct relay
   * @param  _execData Information on jobs to execute
   * @param  _vault Automation vault address to which the call is forwarded
   */
  function exec(IAutomationVault.ExecData[] calldata _execData, IAutomationVault _vault) external;
}
