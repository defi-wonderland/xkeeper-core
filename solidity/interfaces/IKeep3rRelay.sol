// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IKeep3rRelay {
  function automationVault() external returns (address _automationVault);

  function jobToChild(address _basicJob) external returns (address _childJob);

  function exec(address _job, bytes32 _jobData) external;

  function registerJob(address _job, address _jobOwner) external;

  function relay(address _keeperV2, bytes32 _data) external;

  function deployChildJob() external returns (address _childJob);
}
