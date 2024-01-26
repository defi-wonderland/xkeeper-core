// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IGelatoRelay, IAutomationVault} from '@interfaces/IGelatoRelay.sol';
import {IAutomate} from '@interfaces/external/IAutomate.sol';
import {IGelato} from '@interfaces/external/IGelato.sol';

/**
 * @title  GelatoRelay
 * @notice This contract will manage all executions coming from the gelato network
 */
contract GelatoRelay is IGelatoRelay {
  /// @inheritdoc IGelatoRelay
  IAutomate public automate;

  /// @inheritdoc IGelatoRelay
  IGelato public gelato;

  /// @inheritdoc IGelatoRelay
  address public feeCollector;

  constructor(address _automate) {
    automate = IAutomate(_automate);
    gelato = IGelato(automate.gelato());
    feeCollector = gelato.feeCollector();
  }

  function exec(IAutomationVault _automationVault, IAutomationVault.ExecData[] calldata _execData) external {
    // Get the fee details
    (uint256 _fee, address _feeToken) = automate.getFeeDetails();

    // Create fee data
    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData({fee: _fee, feeToken: _feeToken, feeRecipient: feeCollector});

    // Execute the automation vault
    _automationVault.exec(msg.sender, _execData, _feeData);

    // Emit the event
    emit AutomationVaultExecuted(address(_automationVault), msg.sender, _execData, _feeData);
  }
}
