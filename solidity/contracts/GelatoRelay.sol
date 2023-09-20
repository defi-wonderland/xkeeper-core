// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IGelatoRelay, IAutomationVault} from '@interfaces/IGelatoRelay.sol';

contract GelatoRelay is IGelatoRelay {
  /// @inheritdoc IGelatoRelay
  function exec(
    address _automationVault,
    IAutomationVault.ExecData[] calldata _execData,
    IAutomationVault.FeeData[] calldata _feeData
  ) external {
    IAutomationVault(_automationVault).exec(msg.sender, _execData, _feeData);

    emit AutomationVaultExecuted(_automationVault, msg.sender, _execData, _feeData);
  }
}
