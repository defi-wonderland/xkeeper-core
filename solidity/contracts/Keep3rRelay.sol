// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IKeep3rRelay, IAutomationVault} from '@interfaces/IKeep3rRelay.sol';

contract Keep3rRelay is IKeep3rRelay {
  /// @inheritdoc IKeep3rRelay
  function exec(address _automationVault, IAutomationVault.ExecData[] calldata _execData) external {
    IAutomationVault(_automationVault).exec(msg.sender, _execData, new IAutomationVault.FeeData[](0));

    emit AutomationVaultExecuted(_automationVault, msg.sender, _execData);
  }
}
