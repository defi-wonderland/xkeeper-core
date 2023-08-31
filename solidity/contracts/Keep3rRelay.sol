// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IKeep3rRelay} from '@interfaces/IKeep3rRelay.sol';

contract Keep3rRelay is IKeep3rRelay {
  /// @inheritdoc IKeep3rRelay
  address public automationVault;
  /// @inheritdoc IKeep3rRelay
  mapping(address _job => address _childJob) public jobToChild;

  constructor(address _automationVault) payable {
    automationVault = _automationVault;
  }

  /// @inheritdoc IKeep3rRelay
  function exec(address _job, bytes32 _jobData) external {}

  /// @inheritdoc IKeep3rRelay
  function registerJob(address _job, address _jobOwner) external {}

  /// @inheritdoc IKeep3rRelay
  function relay(address _keep3rV2, bytes32 _data) external {}

  /// @inheritdoc IKeep3rRelay
  function deployChildJob() external returns (address _childJob) {}
}
