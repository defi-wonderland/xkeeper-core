// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IAutomationVault {
  event DepositFunds(address indexed _job, address indexed _token, uint256 _amount);
  event WithdrawFunds(address indexed _job, address indexed _token, uint256 _amount, address indexed _receiver);
  event ApproveRelay(address indexed _job, bytes4 _jobSelector, address indexed _relay);
  event RevokeRelay(address indexed _job, bytes4 _jobSelector, address indexed _relay);

  error AutomationVault_InvalidAmount();
  error AutomationVault_ETHTransferFailed();
  error AutomationVault_AlreadyApprovedRelay();
  error AutomationVault_NotApprovedRelay();
  error AutomationVault_OnlyJobOwner(address _jobOwner);
  error AutomationVault_OnlyJobPendingOwner(address _jobPendingOwner);
  error AutomationVault_ReceiveETHNotAvailable();

  function jobOwner(address _job) external returns (address _owner);

  function jobPendingOwner(address _job) external returns (address _pendingOwner);

  function jobApprovedRelays(address _job, bytes4 _jobSelector, address _relay) external returns (bool _approved);

  function jobsBalances(address _job, address _token) external returns (uint256 _balance);

  function registerJob(address _job, address _jobOwner) external;

  function changeJobOwner(address _job, address _jobOwner) external;

  function acceptJobOwner(address _job, address _jobOwner) external;

  function depositFunds(address _job, address _token, uint256 _amount) external payable;

  function withdrawFunds(address _job, address _token, uint256 _amount, address _receiver) external payable;

  function approveRelay(address _job, bytes4 _jobSelector, address _relayToApprove) external;

  function revokeRelay(address _job, bytes4 _jobSelector, address _relayToRevoke) external;

  function issuePayment(address _job, uint256 _fee, address _feeToken, address _feeRecipient) external;
}
