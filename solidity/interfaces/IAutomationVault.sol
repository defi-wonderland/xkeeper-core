// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IAutomationVault {
  event RegisterJob(address indexed _job, address indexed _jobOwner);
  event ChangeJobOwner(address indexed _job, address indexed _jobPendingOwner);
  event AcceptJobOwner(address indexed _job, address indexed _jobOwner);
  event DepositFunds(address indexed _job, address indexed _token, uint256 _amount);
  event WithdrawFunds(address indexed _job, address indexed _token, uint256 _amount, address indexed _receiver);
  event ApproveRelay(address indexed _job, bytes4 _jobSelector, address indexed _relay);
  event RevokeRelay(address indexed _job, bytes4 _jobSelector, address indexed _relay);
  event IssuePayment(
    address indexed _job, bytes4 _jobSelector, uint256 _fee, address indexed _feeToken, address indexed _feeRecipient
  );

  error AutomationVault_JobAlreadyRegistered(address _jobOwner);
  error AutomationVault_InvalidAmount();
  error AutomationVault_InsufficientFunds();
  error AutomationVault_ETHTransferFailed();
  error AutomationVault_AlreadyApprovedRelay();
  error AutomationVault_NotApprovedRelay();
  error AutomationVault_OnlyJobOwner(address _jobOwner);
  error AutomationVault_OnlyJobPendingOwner(address _jobPendingOwner);
  error AutomationVault_ReceiveETHNotAvailable();

  function owner() external view returns (address _owner);

  function organizationName() external view returns (string calldata _organizationName);

  function jobOwner(address _job) external returns (address _owner);

  function jobPendingOwner(address _job) external returns (address _pendingOwner);

  function jobApprovedRelays(address _job, bytes4 _jobSelector, address _relay) external returns (bool _approved);

  function jobsBalances(address _job, address _token) external returns (uint256 _balance);

  function registerJob(address _job, address _jobOwner) external;

  function changeJobOwner(address _job, address _jobPendingOwner) external;

  function acceptJobOwner(address _job) external;

  function depositFunds(address _job, address _token, uint256 _amount) external payable;

  function withdrawFunds(address _job, address _token, uint256 _amount, address _receiver) external payable;

  function approveRelay(address _job, bytes4 _jobSelector, address _relayToApprove) external;

  function revokeRelay(address _job, bytes4 _jobSelector, address _relayToRevoke) external;

  function issuePayment(
    address _job,
    bytes4 _jobSelector,
    uint256 _fee,
    address _feeToken,
    address _feeRecipient
  ) external;
}
