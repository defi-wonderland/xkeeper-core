// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOpenRelay} from '@interfaces/IOpenRelay.sol';

contract OpenRelay is IOpenRelay {
  /// Inheritdoc IOpenRelay
  address public automationVault;

  constructor(address _automationVault) payable {
    automationVault = _automationVault;
  }

  /// Inheritdoc IOpenRelay
  function exec(address _job, bytes32 _jobData, uint256 _fee, address _feeToken, address _feeRecipient) external {}
}
