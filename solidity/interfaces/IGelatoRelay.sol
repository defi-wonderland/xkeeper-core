// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

interface IGelatoRelay {
  /// EVENTS ///
  event AutomationVaultExecuted(
    address indexed _automationVault,
    address indexed _relayCaller,
    IAutomationVault.ExecData[] _execData,
    IAutomationVault.FeeData[] _feeData
  );

  /// EXTERNAL FUNCTIONS ///
  function exec(
    address _automationVault,
    IAutomationVault.ExecData[] calldata _execData,
    IAutomationVault.FeeData[] calldata _feeData
  ) external;
}
