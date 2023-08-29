// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';
import {IERC20, SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';

contract AutomationVault is IAutomationVault {
  using SafeERC20 for IERC20;

  address internal constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /// @inheritdoc IAutomationVault
  mapping(address _job => address _owner) public jobOwner;
  /// @inheritdoc IAutomationVault
  mapping(address _job => address _pendingOwner) public jobPendingOwner;
  /// @inheritdoc IAutomationVault
  mapping(address _job => mapping(address _relay => bool _approved)) public jobApprovedRelays;
  /// @inheritdoc IAutomationVault
  mapping(address _job => mapping(address _token => uint256 _balance)) public jobsBalances;

  /// @inheritdoc IAutomationVault
  function registerJob(address _job, address _jobOwner) external {}

  /// @inheritdoc IAutomationVault
  function changeJobOwner(address _job, address _jobOwner) external onlyJobOwner(_job) {}

  /// @inheritdoc IAutomationVault
  function acceptJobOwner(address _job, address _jobOwner) external onlyJobPendingOwner {}

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
    if (_amount > _balance) revert AutomationVault_InvalidAmount();
    jobsBalances[_job][_token] -= _amount;
    if (_token == _ETH) {
      (bool _success,) = _receiver.call{value: _amount}('');
      if (!_success) revert AutomationVault_EthTransferFailed();
    } else {
      IERC20(_token).safeTransfer(_receiver, _amount);
    }

    emit WithdrawFunds(_job, _token, _amount, _receiver);
  }

  /// @inheritdoc IAutomationVault
  function approveRelays(address _job, address[] calldata _relaysToApprove) external onlyJobOwner(_job) {}

  /// @inheritdoc IAutomationVault
  function revokeRelays(address _job, address[] calldata _relaysToRevoke) external onlyJobOwner(_job) {}

  /// @inheritdoc IAutomationVault
  function issuePayment(address _job, uint256 _fee, address _feeToken, address _feeRecipient) external {}

  modifier onlyJobOwner(address _job) {
    address _jobOwner = jobOwner[_job];
    if (msg.sender != _jobOwner) {
      revert AutomationVault_OnlyJobOwner(_jobOwner);
    }
    _;
  }

  modifier onlyJobPendingOwner() {
    _;
  }

  receive() external payable {
    revert AutomationVault_ReceiveEthNotAvailable();
  }
}
