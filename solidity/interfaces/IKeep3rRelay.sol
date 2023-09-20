// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

interface IKeep3rRelay {
  /// EVENTS ///
  event AutomationVaultExecuted(
    address indexed _automationVault, address indexed _relayCaller, IAutomationVault.ExecData[] _execData
  );

  /// EXTERNAL FUNCTIONS ///
  function exec(address _automationVault, IAutomationVault.ExecData[] calldata _execData) external;
}
