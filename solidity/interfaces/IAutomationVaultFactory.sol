// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

interface IAutomationVaultFactory {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a new automation vault is deployed
   * @param  _owner The address of the owner
   * @param  _organizationName The name of the organization
   * @param  _automationVault The address of the automation vault deployed
   */
  event DeployAutomationVault(
    address indexed _owner, string indexed _organizationName, address indexed _automationVault
  );

  /*///////////////////////////////////////////////////////////////
                              ERRORS  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the amount is zero
   */
  error AutomationVaultFactory_AmountZero();

  /*///////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Get the total amount of automation vaults deployed by the factory
   * @return _totalAutomationVaults The total amount of automation vaults deployed
   */
  function totalAutomationVaults() external view returns (uint256 _totalAutomationVaults);

  /**
   * @notice Get a certain amount of automation vaults deployed by the factory
   * @param  _startFrom Index from where to start retrieving automation vaults
   * @param  _automationVaultAmount Amount of automation vaults to retrieve
   * @return __automationVaults The array of automation vaults
   */
  function automationVaults(
    uint256 _startFrom,
    uint256 _automationVaultAmount
  ) external view returns (address[] memory __automationVaults);

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Deploy a new automation vault
   * @param  _owner The address of the owner
   * @param  _organizationName The name of the organization
   * @return _automationVault The address of the automation vault deployed
   */
  function deployAutomationVault(
    address _owner,
    string calldata _organizationName
  ) external returns (IAutomationVault _automationVault);
}
