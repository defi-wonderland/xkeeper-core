// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IOpenRelay} from '@interfaces/IOpenRelay.sol';
import {IAutomationVault} from '@interfaces/IAutomationVault.sol';
import {_ETH} from '@utils/Constants.sol';

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
    address _automationVault,
    IAutomationVault.ExecData[] calldata _execData,
    address _feeRecipient
  ) external {
    if (_execData.length == 0) revert OpenRelay_NoExecData();

    uint256 _initialGas = gasleft();
    IAutomationVault(_automationVault).exec(msg.sender, _execData, new IAutomationVault.FeeData[](0));
    uint256 _gasSpent = _initialGas - gasleft();
    uint256 _payment = (_gasSpent + GAS_BONUS) * block.basefee * GAS_MULTIPLIER / BASE;

    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData(_feeRecipient, _ETH, _payment);
    IAutomationVault(_automationVault).exec(msg.sender, new IAutomationVault.ExecData[](0), _feeData);

    emit AutomationVaultExecuted(_automationVault, msg.sender, _execData, _feeData);
  }
}
