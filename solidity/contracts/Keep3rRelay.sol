// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IKeep3rRelay, IAutomationVault} from '@interfaces/IKeep3rRelay.sol';
import {IKeep3rV2} from '@interfaces/external/IKeep3rV2.sol';
import {_KEEP3R_V2} from '@utils/Constants.sol';

/**
 * @title  Keep3rRelay
 * @notice This contract will manage all executions coming from the keep3r network
 */
contract Keep3rRelay is IKeep3rRelay {
  /// @inheritdoc IKeep3rRelay
  function exec(address _automationVault, IAutomationVault.ExecData[] calldata _execData) external {
    uint256 _execDataLength = _execData.length;
    if (_execDataLength == 0) revert Keep3rRelay_NoExecData();

    IAutomationVault.ExecData[] memory _execDataKeep3r = new IAutomationVault.ExecData[](_execDataLength + 2);

    _execDataKeep3r[0] = IAutomationVault.ExecData({
      job: _KEEP3R_V2,
      jobData: abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, msg.sender)
    });

    for (uint256 _i; _i < _execDataLength;) {
      if (_execData[_i].job == _KEEP3R_V2) revert Keep3rRelay_Keep3rNotAllowed();
      _execDataKeep3r[_i + 1] = _execData[_i];
      unchecked {
        ++_i;
      }
    }

    _execDataKeep3r[_execDataLength + 1] = IAutomationVault.ExecData({
      job: _KEEP3R_V2,
      jobData: abi.encodeWithSelector(IKeep3rV2.worked.selector, msg.sender)
    });

    IAutomationVault(_automationVault).exec(msg.sender, _execDataKeep3r, new IAutomationVault.FeeData[](0));

    emit AutomationVaultExecuted(_automationVault, msg.sender, _execDataKeep3r);
  }
}
