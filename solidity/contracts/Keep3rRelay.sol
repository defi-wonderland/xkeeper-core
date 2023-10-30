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
    // ensure that calls are being passed
    uint256 _execDataLength = _execData.length;
    if (_execDataLength == 0) revert Keep3rRelay_NoExecData();

    // ensure that the caller is a valid keeper
    bool _isKeeper = IKeep3rV2(_KEEP3R_V2).isKeeper(msg.sender);
    if (!_isKeeper) revert Keep3rRelay_NotKeep3r();

    // create the array of calls which are going to be executed by the automation vault
    IAutomationVault.ExecData[] memory _execDataKeep3r = new IAutomationVault.ExecData[](_execDataLength + 1);

    // inject to that array of calls the exec data provided in the arguments
    for (uint256 _i; _i < _execDataLength;) {
      if (_execData[_i].job == _KEEP3R_V2) revert Keep3rRelay_Keep3rNotAllowed();
      _execDataKeep3r[_i] = _execData[_i];
      unchecked {
        ++_i;
      }
    }

    // inject the final call which will issue the payment to the keeper
    _execDataKeep3r[_execDataLength] = IAutomationVault.ExecData({
      job: _KEEP3R_V2,
      jobData: abi.encodeWithSelector(IKeep3rV2.worked.selector, msg.sender)
    });

    // ensure that the caller is a valid keeper

    // send the array of calls to the automation vault for it to execute them
    IAutomationVault(_automationVault).exec(msg.sender, _execDataKeep3r, new IAutomationVault.FeeData[](0));

    // emit the event
    emit AutomationVaultExecuted(_automationVault, msg.sender, _execDataKeep3r);
  }
}
