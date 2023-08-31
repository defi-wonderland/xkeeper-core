// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IOpenRelay} from '@interfaces/IOpenRelay.sol';

contract OpenRelay is IOpenRelay {
  /// @inheritdoc IOpenRelay
  address public automationVault;

  constructor(address _automationVault) payable {
    automationVault = _automationVault;
  }

  /// @inheritdoc IOpenRelay
  function exec(address _job, bytes32 _jobData, uint256 _fee, address _feeToken, address _feeRecipient) external {}
}
