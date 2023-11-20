// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IGelatoRelay, IAutomationVault} from '@interfaces/IGelatoRelay.sol';

/**
 * @title  GelatoRelay
 * @notice This contract will manage all executions coming from the gelato network
 */
contract GelatoRelay is IGelatoRelay {
  /// @inheritdoc IGelatoRelay
  function exec(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] calldata _execData,
    IAutomationVault.FeeData[] calldata _feeData
  ) external {
    // Execute the automation vault
    _automationVault.exec(msg.sender, _execData, _feeData);

    // Emit the event
    emit AutomationVaultExecuted(address(_automationVault), msg.sender, _execData, _feeData);
  }
}
