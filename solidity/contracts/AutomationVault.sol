// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';
import {IERC20, SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';

contract AutomationVault is IAutomationVault {
  using SafeERC20 for IERC20;

  address internal constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /// @inheritdoc IAutomationVault
  address public owner;
  /// @inheritdoc IAutomationVault
  string public organizationName;

  /// @inheritdoc IAutomationVault
  mapping(address _job => address _owner) public jobOwner;
  /// @inheritdoc IAutomationVault
  mapping(address _job => address _pendingOwner) public jobPendingOwner;
  /// @inheritdoc IAutomationVault
  mapping(address _job => mapping(bytes4 _jobSelector => mapping(address _relay => bool _approved))) public
    jobApprovedRelays;
  /// @inheritdoc IAutomationVault
  mapping(address _job => mapping(address _token => uint256 _balance)) public jobsBalances;

  constructor(address _owner, string memory _organizationName) payable {
    owner = _owner;
    organizationName = _organizationName;
  }

  /// @inheritdoc IAutomationVault
  function registerJob(address _job, address _jobOwner) external {
    address _currentOwner = jobOwner[_job];
    if (_currentOwner != address(0)) revert AutomationVault_JobAlreadyRegistered(_currentOwner);
    jobOwner[_job] = _jobOwner;

    emit RegisterJob(_job, _jobOwner);
  }

  /// @inheritdoc IAutomationVault
  function changeJobOwner(address _job, address _jobPendingOwner) external onlyJobOwner(_job) {
    jobPendingOwner[_job] = _jobPendingOwner;
    emit ChangeJobOwner(_job, _jobPendingOwner);
  }

  /// @inheritdoc IAutomationVault
  function acceptJobOwner(address _job) external onlyJobPendingOwner(_job) {
    jobOwner[_job] = msg.sender;
    delete jobPendingOwner[_job];
    emit AcceptJobOwner(_job, msg.sender);
  }

  /// @inheritdoc IAutomationVault
  function depositFunds(address _job, address _token, uint256 _amount) external payable {
    if (_token == _ETH) {
      if (_amount != msg.value) revert AutomationVault_InvalidAmount();
    } else {
      IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
    }
    jobsBalances[_job][_token] += _amount;
    emit DepositFunds(_job, _token, _amount);
  }

  /// @inheritdoc IAutomationVault
  function withdrawFunds(
    address _job,
    address _token,
    uint256 _amount,
    address _receiver
  ) external payable onlyJobOwner(_job) {
    uint256 _balance = jobsBalances[_job][_token];
    if (_amount > _balance) revert AutomationVault_InsufficientFunds();
    jobsBalances[_job][_token] -= _amount;
    if (_token == _ETH) {
      (bool _success,) = _receiver.call{value: _amount}('');
      if (!_success) revert AutomationVault_ETHTransferFailed();
    } else {
      IERC20(_token).safeTransfer(_receiver, _amount);
    }

    emit WithdrawFunds(_job, _token, _amount, _receiver);
  }

  /// @inheritdoc IAutomationVault
  function approveRelay(address _job, bytes4 _jobSelector, address _relayToApprove) external onlyJobOwner(_job) {
    if (jobApprovedRelays[_job][_jobSelector][_relayToApprove]) revert AutomationVault_AlreadyApprovedRelay();
    jobApprovedRelays[_job][_jobSelector][_relayToApprove] = true;
    emit ApproveRelay(_job, _jobSelector, _relayToApprove);
  }

  /// @inheritdoc IAutomationVault
  function revokeRelay(address _job, bytes4 _jobSelector, address _relayToRevoke) external onlyJobOwner(_job) {
    if (!jobApprovedRelays[_job][_jobSelector][_relayToRevoke]) revert AutomationVault_NotApprovedRelay();
    jobApprovedRelays[_job][_jobSelector][_relayToRevoke] = false;
    emit RevokeRelay(_job, _jobSelector, _relayToRevoke);
  }

  /// @inheritdoc IAutomationVault
  function issuePayment(
    address _job,
    bytes4 _jobSelector,
    uint256 _fee,
    address _feeToken,
    address _feeRecipient
  ) external {
    if (!jobApprovedRelays[_job][_jobSelector][msg.sender]) revert AutomationVault_NotApprovedRelay();
    if (_fee > jobsBalances[_job][_feeToken]) revert AutomationVault_InsufficientFunds();

    if (_feeToken == _ETH) {
      (bool _success,) = _feeRecipient.call{value: _fee}('');
      if (!_success) revert AutomationVault_ETHTransferFailed();
    } else {
      IERC20(_feeToken).safeTransfer(_feeRecipient, _fee);
    }

    emit IssuePayment(_job, _jobSelector, _fee, _feeToken, _feeRecipient);
  }

  modifier onlyJobOwner(address _job) {
    address _jobOwner = jobOwner[_job];
    if (msg.sender != _jobOwner) revert AutomationVault_OnlyJobOwner(_jobOwner);
    _;
  }

  modifier onlyJobPendingOwner(address _job) {
    address _jobPendingOwner = jobPendingOwner[_job];
    if (msg.sender != _jobPendingOwner) revert AutomationVault_OnlyJobPendingOwner(_jobPendingOwner);
    _;
  }

  receive() external payable {
    revert AutomationVault_ReceiveETHNotAvailable();
  }
}
