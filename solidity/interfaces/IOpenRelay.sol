// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

interface IOpenRelay {
  /// EVENTS ///
  event AutomationVaultExecuted(
    address indexed _automationVault,
    address indexed _relayCaller,
    IAutomationVault.ExecData[] _execData,
    IAutomationVault.FeeData[] _feeData
  );

  /// ERRORS ///
  error OpenRelay_NoExecData();

  /// VIEW FUNCTIONS ///
  function GAS_BONUS() external view returns (uint256 _gasBonus);

  function GAS_MULTIPLIER() external view returns (uint256 _gasMultiplier);

  function BASE() external view returns (uint32 _base);

  /// EXTERNAL FUNCTIONS ///
  function exec(
    address _automationVault,
    IAutomationVault.ExecData[] calldata _execData,
    address _feeRecipient
  ) external;
}
