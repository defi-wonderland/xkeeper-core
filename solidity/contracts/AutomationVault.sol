// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

contract AutomationVault is IAutomationVault {
  /// Inheritdoc IAutomationVault
  mapping(address _job => address _owner) public jobOwner;
  /// Inheritdoc IAutomationVault
  mapping(address _job => address _pendingOwner) public jobPendingOwner;
  /// Inheritdoc IAutomationVault
  mapping(address _job => mapping(address _relay => bool _approved)) public jobApprovedRelays;
  /// Inheritdoc IAutomationVault
  mapping(address _job => mapping(address _token => uint256 _balance)) public jobsBalances;

  /// Inheritdoc IAutomationVault
  function registerJob(address _job, address _jobOwner) external {}

  /// Inheritdoc IAutomationVault
  function changeJobOwner(address _job, address _jobOwner) external onlyJobOwner {}

  /// Inheritdoc IAutomationVault
  function acceptJobOwner(address _job, address _jobOwner) external onlyJobPendingOwner {}

  /// Inheritdoc IAutomationVault
  function depositFunds(address _job, address _token, uint256 _amount) external payable onlyJobOwner {}

  /// Inheritdoc IAutomationVault
  function withdrawFunds(
    address _job,
    address _token,
    uint256 _amount,
    address _receiver
  ) external payable onlyJobOwner {}

  /// Inheritdoc IAutomationVault
  function approveRelays(address _job, address[] calldata _relaysToApprove) external onlyJobOwner {}

  /// Inheritdoc IAutomationVault
  function revokeRelays(address _job, address[] calldata _relaysToRevoke) external onlyJobOwner {}

  /// Inheritdoc IAutomationVault
  function issuePayment(address _job, uint256 _fee, address _feeToken, address _feeRecipient) external {}

  modifier onlyJobOwner() {
    _;
  }

  modifier onlyJobPendingOwner() {
    _;
  }

  receive() external payable {}
}
