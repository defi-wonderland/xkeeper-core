// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';
import {IKeep3rRelay} from '@interfaces/IKeep3rRelay.sol';

interface IKeep3rBondedRelay is IKeep3rRelay {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the automation vault requirements are setted
   * @param  _bond T
   * @param  _minBond T
   * @param  _earned T
   * @param  _age T
   */
  event AutomationVaultRequirementsSetted(
    address indexed _automationVault, uint256 _bond, uint256 _minBond, uint256 _earned, uint256 _age
  );

  /*///////////////////////////////////////////////////////////////
                              ERRORS  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not the automation vault owner
   */
  error IKeeperBondedRelay_NotVaultOwner();

  /**
   * @notice Thrown when the automation automation vault requirements are not setted
   */
  error IKeeperBondedRelay_NotAutomationVaultRequirement();

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The data to execute a job
   * @param  _bond T
   * @param  _minBond T
   * @param  _earned T
   * @param  _age T
   */
  struct Requirements {
    uint256 bond;
    uint256 minBond;
    uint256 earned;
    uint256 age;
  }

  /*///////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Get the automation vault requirements
   * @param  _automationVault The address of the automation vault
   * @return _bond T
   * @return _minBond T
   * @return _earned T
   * @return _age T
   */
  function automationVaultRequirements(address _automationVault)
    external
    view
    returns (uint256 _bond, uint256 _minBond, uint256 _earned, uint256 _age);

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice
   * @dev    Only the owner of the automation vault can set the requirements
   * @param  _automationVault The address of the automation vault
   * @param  _bond T
   * @param  _minBond T
   * @param  _earned T
   * @param  _age T
   */
  function setAutomationVaultRequirements(
    address _automationVault,
    uint256 _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) external;
}
