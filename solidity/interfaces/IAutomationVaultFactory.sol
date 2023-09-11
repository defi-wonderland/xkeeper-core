// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

interface IAutomationVaultFactory {
  event DeployAutomationVault(
    address indexed _owner, string indexed _organizationName, address indexed _automationVault
  );

  function automationVaults() external view returns (address[] memory __automationVaults);

  function deployAutomationVault(
    address _owner,
    string calldata _organizationName
  ) external returns (IAutomationVault _automationVault);
}
