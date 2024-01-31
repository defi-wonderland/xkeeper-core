// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IBasicJob {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when work is done
   */
  event Worked();

  /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice This function will be called by automation vaults
   */
  function work() external;

  /**
   * @notice This function will be called by automation vaults
   * @param _howHard How hard the job should work
   */
  function workHard(uint256 _howHard) external;
}
