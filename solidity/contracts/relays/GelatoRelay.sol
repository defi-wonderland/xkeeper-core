// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IGelatoRelay, IAutomationVault} from '@interfaces/relays/IGelatoRelay.sol';

/**
 * @title  GelatoRelay
 * @notice This contract will manage all executions coming from the gelato network
 */
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
