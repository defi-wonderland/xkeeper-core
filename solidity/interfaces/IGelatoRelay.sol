// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IGelatoRelay {
  function automationVault() external returns (address _automationVault);

  function exec(address _job, bytes32 _jobData, uint256 _fee, address _feeToken, address _feeRecipient) external;
}
