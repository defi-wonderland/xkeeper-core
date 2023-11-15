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
   * @notice Get the automation vaults deployed by the factory
   * @return __automationVaults The array of automation vaults
   */
  function automationVaults() external view returns (address[] memory __automationVaults);

  /**
   * @notice Get the automation vaults deployed by the factory in a paginated format
   * @param  _startFrom Index from where to start the pagination
   * @param  _amount Maximum amount of automation vaults to retrieve
   * @return _paginatedAutomationVaults The array of automation vaults
   */
  function paginatedAutomationVaults(
    uint256 _startFrom,
    uint256 _amount
  ) external view returns (address[] memory _paginatedAutomationVaults);

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
