// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IAutomationVault {
  function jobOwner(address _job) external returns (address _owner);

  function jobPendingOwner(address _job) external returns (address _pendingOwner);

  function jobApprovedRelays(address _job, address _relay) external returns (bool _approved);

  function jobsBalances(address _job, address _relay) external returns (uint256 _balance);

  function registerJob(address _job, address _jobOwner) external;

  function changeJobOwner(address _job, address _jobOwner) external;

  function acceptJobOwner(address _job, address _jobOwner) external;

  function depositFunds(address _job, address _token, uint256 _amount) external payable;

  function withdrawFunds(address _job, address _token, uint256 _amount, address _receiver) external payable;

  function approveRelays(address _job, address[] memory _relaysToApprove) external;

  function revokeRelays(address _job, address[] memory _relaysToRevoke) external;

  function issuePayment(address _job, uint256 _fee, address _feeToken, address _feeRecipient) external;
}
