// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IAutomate} from '@interfaces/external/IAutomate.sol';
import {IGelato} from '@interfaces/external/IGelato.sol';
import {IGelatoRelay, IAutomationVault} from '@interfaces/relays/IGelatoRelay.sol';

/**
 * @title  GelatoRelay
 * @notice This contract will manage all executions coming from the gelato network
 */
contract GelatoRelay is IGelatoRelay {
  /// @inheritdoc IGelatoRelay
  IAutomate public immutable AUTOMATE;

  /// @inheritdoc IGelatoRelay
  address public immutable FEE_COLLECTOR;

  /**
   * @param _automate The automate contract of the gelato network
   */
  constructor(IAutomate _automate) {
    AUTOMATE = _automate;
    FEE_COLLECTOR = IGelato(AUTOMATE.gelato()).feeCollector();
  }

  /// @inheritdoc IGelatoRelay
  function exec(IAutomationVault _automationVault, IAutomationVault.ExecData[] calldata _execData) external {
    // Get the fee details
    (uint256 _fee, address _feeToken) = AUTOMATE.getFeeDetails();

    // Create fee data
    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData(FEE_COLLECTOR, _feeToken, _fee);

    // Execute the automation vault
    _automationVault.exec(msg.sender, _execData, _feeData);

    // Emit the event
    emit AutomationVaultExecuted(_automationVault, msg.sender, _execData, _feeData);
  }
}
