// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IGelatoRelay} from '@interfaces/IGelatoRelay.sol';
import {AutomateReady} from './utils/AutomateReady.sol';

contract GelatoRelay is IGelatoRelay, AutomateReady {
  /// Inheritdoc IGelatoRelay
  address public automationVault;

  constructor(
    address _automationVault,
    address _automate,
    address _taskCreator
  ) payable AutomateReady(_automate, _taskCreator) {
    automationVault = _automationVault;
  }

  /// Inheritdoc IGelatoRelay
  function exec(address _job, bytes32 _jobData, uint256 _fee, address _feeToken, address _feeRecipient) external {}
}
