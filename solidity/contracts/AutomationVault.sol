// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';
import {IERC20, SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';
import {_ALL} from '@utils/Constants.sol';

/**
 * @title  AutomationVault
 * @notice This contract is used for managing the execution of jobs using several relays and paying them for their work
 */
contract AutomationVault is IAutomationVault {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  /// @inheritdoc IAutomationVault
  address public owner;
  /// @inheritdoc IAutomationVault
  address public pendingOwner;
  /// @inheritdoc IAutomationVault
  address public immutable nativeToken;
  /**
   * @notice Callers that are approved to call a relay
   */
  mapping(address _relay => EnumerableSet.AddressSet _enabledCallers) internal _relayEnabledCallers;

  /**
   * @notice Selectors that are approved to be called
   */
  mapping(address _job => EnumerableSet.Bytes32Set _enabledSelectors) internal _jobEnabledSelectors;

  /**
   * @notice List of approved relays
   */
  EnumerableSet.AddressSet internal _relays;

  /**
   * @notice List of approved jobs
   */
  EnumerableSet.AddressSet internal _jobs;

  /**
   * @param _owner The address of the owner
   */
  constructor(address _owner, address _nativeToken) {
    owner = _owner;
    nativeToken = _nativeToken;
  }

  /// @inheritdoc IAutomationVault
  function relayEnabledCallers(address _relay) external view returns (address[] memory _enabledCallers) {
    _enabledCallers = _relayEnabledCallers[_relay].values();
  }

  /// @inheritdoc IAutomationVault
  function jobEnabledSelectors(address _job) external view returns (bytes32[] memory _enabledSelectors) {
    _enabledSelectors = _jobEnabledSelectors[_job].values();
  }

  /// @inheritdoc IAutomationVault
  function relays() external view returns (address[] memory _relayList) {
    _relayList = _relays.values();
  }

  /// @inheritdoc IAutomationVault
  function jobs() external view returns (address[] memory _jobList) {
    _jobList = _jobs.values();
  }

  /// @inheritdoc IAutomationVault
  function changeOwner(address _pendingOwner) external onlyOwner {
    pendingOwner = _pendingOwner;
    emit ChangeOwner(_pendingOwner);
  }

  /// @inheritdoc IAutomationVault
  function acceptOwner() external onlyPendingOwner {
    pendingOwner = address(0);
    owner = msg.sender;
    emit AcceptOwner(msg.sender);
  }

  /// @inheritdoc IAutomationVault
  function withdrawFunds(address _token, uint256 _amount, address _receiver) external onlyOwner {
    // If the token is the native token, transfer the funds to the receiver, otherwise transfer the tokens
    if (_token == nativeToken) {
      (bool _success,) = _receiver.call{value: _amount}('');
      if (!_success) revert AutomationVault_NativeTokenTransferFailed();
    } else {
      IERC20(_token).safeTransfer(_receiver, _amount);
    }

    // Emit the event
    emit WithdrawFunds(_token, _amount, _receiver);
  }

  /// @inheritdoc IAutomationVault
  function approveRelayCallers(address _relay, address[] calldata _callers) external onlyOwner {
    // Get the list of enabled callers for the relay
    EnumerableSet.AddressSet storage _enabledCallers = _relayEnabledCallers[_relay];

    // If the relay is not approved, add it to the list of relays
    if (_relays.add(_relay)) {
      emit ApproveRelay(_relay);
    }

    // Iterate over the callers to approve them
    for (uint256 _i; _i < _callers.length;) {
      if (_enabledCallers.add(_callers[_i])) {
        emit ApproveRelayCaller(_relay, _callers[_i]);
      }

      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IAutomationVault
  function revokeRelayCallers(address _relay, address[] calldata _callers) external onlyOwner {
    // Get the list of enabled callers for the relay
    EnumerableSet.AddressSet storage _enabledCallers = _relayEnabledCallers[_relay];

    // Iterate over the callers to revoke them
    for (uint256 _i; _i < _callers.length;) {
      if (_enabledCallers.remove(_callers[_i])) {
        emit RevokeRelayCaller(_relay, _callers[_i]);
      }

      unchecked {
        ++_i;
      }
    }

    // If the relay has no more callers, remove it from the list of relays
    if (_enabledCallers.length() == 0) {
      _relays.remove(_relay);
      emit RevokeRelay(_relay);
    }
  }

  /// @inheritdoc IAutomationVault
  function approveJobSelectors(address _job, bytes4[] calldata _functionSelectors) external onlyOwner {
    // Get the list of enabled selectors for the job
    EnumerableSet.Bytes32Set storage _enabledSelectors = _jobEnabledSelectors[_job];

    // If the job is not approved, add it to the list of jobs
    if (_jobs.add(_job)) {
      emit ApproveJob(_job);
    }

    // Iterate over the selectors to approve them
    for (uint256 _i; _i < _functionSelectors.length;) {
      if (_enabledSelectors.add(_functionSelectors[_i])) {
        emit ApproveJobSelector(_job, _functionSelectors[_i]);
      }

      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IAutomationVault
  function revokeJobSelectors(address _job, bytes4[] calldata _functionSelectors) external onlyOwner {
    // Get the list of enabled selectors for the job
    EnumerableSet.Bytes32Set storage _enabledSelectors = _jobEnabledSelectors[_job];

    // Iterate over the selectors to revoke them
    for (uint256 _i; _i < _functionSelectors.length;) {
      if (_enabledSelectors.remove(_functionSelectors[_i])) {
        emit RevokeJobSelector(_job, _functionSelectors[_i]);
      }

      unchecked {
        ++_i;
      }
    }

    // If the job has no more selectors, remove it from the list of jobs
    if (_enabledSelectors.length() == 0) {
      _jobs.remove(_job);
      emit RevokeJob(_job);
    }
  }

  /// @inheritdoc IAutomationVault
  function exec(address _relayCaller, ExecData[] calldata _execData, FeeData[] calldata _feeData) external {
    // Check that the specific caller is approved to call the relay
    if (!_relayEnabledCallers[msg.sender].contains(_relayCaller) && !_relayEnabledCallers[msg.sender].contains(_ALL)) {
      revert AutomationVault_NotApprovedRelayCaller();
    }

    // Create the exec data needed variables
    ExecData memory _dataToExecute;
    uint256 _dataLength = _execData.length;
    uint256 _i;
    bool _success;

    // Iterate over the exec data to execute the jobs
    for (_i; _i < _dataLength;) {
      _dataToExecute = _execData[_i];

      // Check that the selector is approved to be called
      if (!_jobEnabledSelectors[_dataToExecute.job].contains(bytes4(_dataToExecute.jobData))) {
        revert AutomationVault_NotApprovedJobSelector();
      }
      (_success,) = _dataToExecute.job.call(_dataToExecute.jobData);
      if (!_success) revert AutomationVault_ExecFailed();

      // Emit the event
      emit JobExecuted(msg.sender, _relayCaller, _dataToExecute.job, _dataToExecute.jobData);

      unchecked {
        ++_i;
      }
    }

    // Create the fee data needed variables
    FeeData memory _feeInfo;
    _dataLength = _feeData.length;
    _i = 0;

    // Iterate over the fee data to issue the payments
    for (_i; _i < _dataLength;) {
      _feeInfo = _feeData[_i];

      // If the token is the native token, transfer the funds to the receiver, otherwise transfer the tokens
      if (_feeInfo.feeToken == nativeToken) {
        (_success,) = _feeInfo.feeRecipient.call{value: _feeInfo.fee}('');
        if (!_success) revert AutomationVault_NativeTokenTransferFailed();
      } else {
        IERC20(_feeInfo.feeToken).safeTransfer(_feeInfo.feeRecipient, _feeInfo.fee);
      }

      // Emit the event
      emit IssuePayment(msg.sender, _relayCaller, _feeInfo.feeRecipient, _feeInfo.feeToken, _feeInfo.fee);

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @notice Checks that the caller is the owner
   */
  modifier onlyOwner() {
    address _owner = owner;
    if (msg.sender != _owner) revert AutomationVault_OnlyOwner();
    _;
  }

  /**
   * @notice Checks that the caller is the pending owner
   */
  modifier onlyPendingOwner() {
    address _pendingOwner = pendingOwner;
    if (msg.sender != _pendingOwner) revert AutomationVault_OnlyPendingOwner();
    _;
  }

  /**
   * @notice Fallback function to receive native tokens
   */
  receive() external payable {
    emit NativeTokenReceived(msg.sender, msg.value);
  }
}
