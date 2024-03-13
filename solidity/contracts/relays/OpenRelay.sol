// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IOpenRelay} from '@interfaces/relays/IOpenRelay.sol';
import {IAutomationVault} from '@interfaces/core/IAutomationVault.sol';
import {_NATIVE_TOKEN} from '@utils/Constants.sol';

/**
 * @title  OpenRelay
 * @notice This contract will manage all executions coming from any bot
 */
contract OpenRelay is IOpenRelay {
  /// @inheritdoc IOpenRelay
  uint256 public constant GAS_BONUS = 53_000;
  /// @inheritdoc IOpenRelay
  uint256 public constant GAS_MULTIPLIER = 12_000;
  /// @inheritdoc IOpenRelay
  uint32 public constant BASE = 10_000;

  /// @inheritdoc IOpenRelay
  function exec(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] calldata _execData,
    address _feeRecipient
  ) external {
    if (_execData.length == 0) revert OpenRelay_NoExecData();

    // Execute the automation vault counting the gas spent
    uint256 _initialGas = gasleft();
    _automationVault.exec(msg.sender, _execData, new IAutomationVault.FeeData[](0));
    uint256 _gasSpent = _initialGas - gasleft();

    // Calculate the payment for the relayer
    uint256 _payment = (_gasSpent + GAS_BONUS) * block.basefee * GAS_MULTIPLIER / BASE;

    // Send the payment to the relayer
    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData(_feeRecipient, _NATIVE_TOKEN, _payment);
    _automationVault.exec(msg.sender, new IAutomationVault.ExecData[](0), _feeData);

    // Emit the event
    emit AutomationVaultExecuted(_automationVault, msg.sender, _execData, _feeData);
  }
}
