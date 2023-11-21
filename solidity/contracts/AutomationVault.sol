// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';
import {IERC20, SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';
import {_ETH, _NULL} from '@utils/Constants.sol';

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
  constructor(address _owner) payable {
    owner = _owner;
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
  function relays() external view returns (address[] memory __relays) {
    __relays = _relays.values();
  }

  /// @inheritdoc IAutomationVault
  function jobs() external view returns (address[] memory __jobs) {
    __jobs = _jobs.values();
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
  function withdrawFunds(address _token, uint256 _amount, address _receiver) external payable onlyOwner {
    // If the token is ETH, transfer the funds to the receiver, otherwise transfer the tokens
    if (_token == _ETH) {
      (bool _success,) = _receiver.call{value: _amount}('');
      if (!_success) revert AutomationVault_ETHTransferFailed();
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
  function exec(address _relayCaller, ExecData[] calldata _execData, FeeData[] calldata _feeData) external payable {
    // Check that the specific caller is approved to call the relay
    if (!_relayEnabledCallers[msg.sender].contains(_relayCaller) && !_relayEnabledCallers[msg.sender].contains(_NULL)) {
      revert AutomationVault_NotApprovedRelayCaller();
    }

    // Create the exec data needed variables
    ExecData memory _execDatum;
    uint256 _dataLength = _execData.length;
    uint256 _i;
    bool _success;

    // Iterate over the exec data to execute the jobs
    for (_i; _i < _dataLength;) {
      _execDatum = _execData[_i];

      // Check that the selector is approved to be called
      if (!_jobEnabledSelectors[_execDatum.job].contains(bytes4(_execDatum.jobData))) {
        revert AutomationVault_NotApprovedJobSelector();
      }
      (_success,) = _execDatum.job.call(_execDatum.jobData);
      if (!_success) revert AutomationVault_ExecFailed();

      // Emit the event
      emit JobExecuted(msg.sender, _relayCaller, _execDatum.job, _execDatum.jobData);

      unchecked {
        ++_i;
      }
    }

    // Create the fee data needed variables
    FeeData memory _feeDatum;
    _dataLength = _feeData.length;
    _i = 0;

    // Iterate over the fee data to issue the payments
    for (_i; _i < _dataLength;) {
      _feeDatum = _feeData[_i];

      // If the token is ETH, transfer the funds to the receiver, otherwise transfer the tokens
      if (_feeDatum.feeToken == _ETH) {
        (_success,) = _feeDatum.feeRecipient.call{value: _feeDatum.fee}('');
        if (!_success) revert AutomationVault_ETHTransferFailed();
      } else {
        IERC20(_feeDatum.feeToken).safeTransfer(_feeDatum.feeRecipient, _feeDatum.fee);
      }

      // Emit the event
      emit IssuePayment(msg.sender, _relayCaller, _feeDatum.feeRecipient, _feeDatum.feeToken, _feeDatum.fee);

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
    if (msg.sender != _owner) revert AutomationVault_OnlyOwner(_owner);
    _;
  }

  /**
   * @notice Checks that the caller is the pending owner
   */
  modifier onlyPendingOwner() {
    address _pendingOwner = pendingOwner;
    if (msg.sender != _pendingOwner) revert AutomationVault_OnlyPendingOwner(_pendingOwner);
    _;
  }

  /**
   * @notice Fallback function to receive ETH
   */
  receive() external payable {
    emit ETHReceived(msg.sender, msg.value);
  }
}
