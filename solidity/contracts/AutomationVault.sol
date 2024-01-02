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
  mapping(address _relay => EnumerableSet.AddressSet _enabledCallers) internal _relayCallers;

  /**
   * @notice Relays that are approved to execute jobs with an specific selector
   */
  mapping(address _relay => mapping(address _job => EnumerableSet.Bytes32Set _enabledSelectors)) internal
    _relayJobSelectors;

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
  function getRelayData(
    address _relay,
    address _job
  ) public view returns (address[] memory _callers, bytes32[] memory _selectors) {
    // Get the list of callers
    _callers = _relayCallers[_relay].values();

    // Get the list of selectors
    _selectors = _relayJobSelectors[_relay][_job].values();
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
  function approveRelayData(
    address _relay,
    address[] calldata _callers,
    IAutomationVault.JobData[] calldata _jobsData
  ) external onlyOwner {
    if (_relay == address(0)) revert AutomationVault_RelayZero();

    // If the relay is not approved, add it to the list of relays
    if (_relays.add(_relay)) {
      emit ApproveRelay(_relay);
    }

    // Iterate over the callers to approve them
    for (uint256 _i; _i < _callers.length;) {
      if (_relayCallers[_relay].add(_callers[_i])) {
        emit ApproveRelayCaller(_relay, _callers[_i]);
      }

      unchecked {
        ++_i;
      }
    }

    // Iterate over the jobs to approve them and their selectors
    for (uint256 _i; _i < _jobsData.length;) {
      IAutomationVault.JobData memory _jobData = _jobsData[_i];

      // If the job is not approved, add it to the list of relays
      if (_jobs.add(_jobData.job)) {
        emit ApproveJob(_jobData.job);
      }

      // Iterate over the selectors to approve them
      for (uint256 _j; _j < _jobData.functionSelectors.length;) {
        if (_relayJobSelectors[_relay][_jobData.job].add(_jobData.functionSelectors[_j])) {
          emit ApproveJobSelector(_jobData.job, _jobData.functionSelectors[_j]);
        }

        unchecked {
          ++_j;
        }
      }

      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IAutomationVault
  function revokeRelayData(
    address _relay,
    address[] calldata _callers,
    IAutomationVault.JobData[] calldata _jobsData
  ) external onlyOwner {
    if (_relay == address(0)) revert AutomationVault_RelayZero();

    // Iterate over the callers to revoke them
    for (uint256 _i; _i < _callers.length;) {
      if (_relayCallers[_relay].remove(_callers[_i])) {
        emit RevokeRelayCaller(_relay, _callers[_i]);
      }

      unchecked {
        ++_i;
      }
    }

    // If the relay has no enabled callers, remove it from the list of relays
    if (_relayCallers[_relay].length() == 0) {
      _relays.remove(_relay);
      emit RevokeRelay(_relay);
    }

    // Iterate over the jobs to revoke them and their selectors
    for (uint256 _i; _i < _jobsData.length;) {
      IAutomationVault.JobData memory _jobData = _jobsData[_i];

      // Iterate over the selectors to revoke them
      for (uint256 _j; _j < _jobData.functionSelectors.length;) {
        if (_relayJobSelectors[_relay][_jobData.job].remove(_jobData.functionSelectors[_j])) {
          emit RevokeJobSelector(_jobData.job, _jobData.functionSelectors[_j]);
        }

        unchecked {
          ++_j;
        }
      }

      if (_relayJobSelectors[_relay][_jobData.job].length() == 0) {
        _jobs.remove(_jobData.job);
        emit RevokeJob(_jobData.job);
      }

      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IAutomationVault
  function exec(address _relayCaller, ExecData[] calldata _execData, FeeData[] calldata _feeData) external {
    // Check that the specific caller is approved to call the relay
    if (!_relayCallers[msg.sender].contains(_relayCaller) && !_relayCallers[msg.sender].contains(_ALL)) {
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
      if (!_relayJobSelectors[msg.sender][_dataToExecute.job].contains(bytes4(_dataToExecute.jobData))) {
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
