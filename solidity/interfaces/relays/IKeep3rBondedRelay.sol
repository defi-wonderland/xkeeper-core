// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/core/IAutomationVault.sol';
import {IKeep3rRelay} from '@interfaces/relays/IKeep3rRelay.sol';

interface IKeep3rBondedRelay is IKeep3rRelay {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the automation vault requirements are setted
   * @param _automationVault The address of the automation vault
   * @param _bond The bond token being evaluated
   * @param _minBond The minimum amount of bonded tokens
   * @param _earned The minimum funds earned in the keepers lifetime
   * @param _age The minimum keeper age required
   */
  event AutomationVaultRequirementsSetted(
    address indexed _automationVault, address _bond, uint256 _minBond, uint256 _earned, uint256 _age
  );

  /*///////////////////////////////////////////////////////////////
                              ERRORS  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not the automation vault owner
   */
  error Keep3rBondedRelay_NotVaultOwner();

  /**
   * @notice Thrown when the automation vault requirements are not setted
   */
  error Keep3rBondedRelay_NotAutomationVaultRequirement();

  /**
   * @notice Thrown when the keeper doesn't meet the requirements set by the automation vault
   */
  error Keep3rBondedRelay_NotBondedKeeper();

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The requirements needed when bonded job is required
   * @param _keeper The address of the keeper to check
   * @param _bond The bond token being evaluated
   * @param _minBond The minimum amount of bonded tokens
   * @param _earned The minimum funds earned in the keepers lifetime
   * @param _age The minimum keeper age required
   */
  struct Requirements {
    address bond;
    uint256 minBond;
    uint256 earned;
    uint256 age;
  }

  /*///////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Get the automation vault bonded requirements
   * @param _automationVault The automation vault
   * @return _bond The bond token being evaluated
   * @return _minBond The minimum amount of bonded tokens
   * @return _earned The minimum funds earned in the keepers lifetime
   * @return _age The minimum keeper age required
   */
  function automationVaultRequirements(IAutomationVault _automationVault)
    external
    view
    returns (address _bond, uint256 _minBond, uint256 _earned, uint256 _age);

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Set the automation vault requirements when bonded job is required
   * @dev    Only the owner of the automation vault can set the requirements
   * @param _automationVault The automation vault that will be executed
   * @param _requirements The requirements needed when bonded job is required
   */
  function setAutomationVaultRequirements(
    IAutomationVault _automationVault,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) external;
}
