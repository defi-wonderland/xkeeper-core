// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/core/IAutomationVault.sol';
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
  address public immutable NATIVE_TOKEN;
  /// @inheritdoc IAutomationVault
  address public owner;
  /// @inheritdoc IAutomationVault
  address public pendingOwner;
  /**
   * @notice Callers approved to call a relay
   */
  mapping(address _relay => EnumerableSet.AddressSet _callers) internal _approvedCallers;

  /**
   * @notice Jobs approved to be executed by a relay
   */
  mapping(address _relay => EnumerableSet.AddressSet _jobs) internal _approvedJobs;

  /**
   * @notice Selectors approved to be executed by a relay for a specific job and type
   */
  mapping(address _relay => mapping(address _job => mapping(bytes4 _selector => IAutomationVault.HookData))) internal
    _approvedJobSelectorsWithHooks;

  /**
   * @notice List of approved relays
   */
  mapping(address _relay => mapping(address _job => bytes4[] _selectors)) internal _approvedJobSelectorsList;

  /**
   * @notice List of approved relays
   */
  EnumerableSet.AddressSet internal _relays;

  /**
   * @param _owner The address of the owner
   */
  constructor(address _owner, address _nativeToken) {
    owner = _owner;
    NATIVE_TOKEN = _nativeToken;
  }

  /// @inheritdoc IAutomationVault
  function getRelayData(address _relay)
    external
    view
    returns (address[] memory _callers, IAutomationVault.JobData[] memory _jobsData)
  {
    // Get the list of callers
    _callers = _approvedCallers[_relay].values();

    // Get the list of all jobs
    address[] memory _jobs = _approvedJobs[_relay].values();

    // Get the length of the jobs array
    uint256 _jobsLength = _jobs.length;

    // Create the array of jobs data with the jobs length
    _jobsData = new IAutomationVault.JobData[](_jobsLength);

    uint256 _selectorsLength;

    // Get the list of jobs and their selectors
    for (uint256 _i; _i < _jobsLength;) {
      // Get the length of the selectors array
      _selectorsLength = _approvedJobSelectorsList[_relay][_jobs[_i]].length;

      // Create the array of selectors data with the selectors length
      SelectorData[] memory _selectorsData;

      // If the job has selectors, get them
      if (_selectorsLength != 0) {
        // Set the length of the selectors array
        _selectorsData = new SelectorData[](_selectorsLength);

        // Get the list of selectors
        for (uint256 _j; _j < _selectorsLength;) {
          _selectorsData[_j].selector = _approvedJobSelectorsList[_relay][_jobs[_i]][_j];
          _selectorsData[_j].hookData = _approvedJobSelectorsWithHooks[_relay][_jobs[_i]][_selectorsData[_j].selector];

          unchecked {
            ++_j;
          }
        }
      }

      // Add the job and its selectors to the full list
      _jobsData[_i] = IAutomationVault.JobData(_jobs[_i], _selectorsData);

      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IAutomationVault
  function relays() external view returns (address[] memory _relayList) {
    _relayList = _relays.values();
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
    if (_token == NATIVE_TOKEN) {
      (bool _success,) = _receiver.call{value: _amount}('');
      if (!_success) revert AutomationVault_NativeTokenTransferFailed();
    } else {
      IERC20(_token).safeTransfer(_receiver, _amount);
    }

    // Emit the event
    emit WithdrawFunds(_token, _amount, _receiver);
  }

  /// @inheritdoc IAutomationVault
  function addRelay(
    address _relay,
    address[] calldata _callers,
    IAutomationVault.JobData[] calldata _jobsData
  ) external onlyOwner {
    if (_relay == address(0)) revert AutomationVault_RelayZero();

    // If the relay is not in the list of relays, add it
    if (!_relays.add(_relay)) revert AutomationVault_RelayAlreadyApproved();
    emit ApproveRelay(_relay);

    // Create the counters variables
    uint256 _i;
    uint256 _j;

    // Create the length variables
    uint256 _valuesLength = _callers.length;

    // Set the callers for the relay
    for (_i; _i < _valuesLength;) {
      if (_approvedCallers[_relay].add(_callers[_i])) {
        emit ApproveRelayCaller(_relay, _callers[_i]);
      }

      unchecked {
        ++_i;
      }
    }

    // Get the length of the jobs data array
    _valuesLength = _jobsData.length;

    // Create the selector length variable
    uint256 _selectorsLength;

    // Set the jobs and their selectors for the relay
    for (_i = 0; _i < _valuesLength;) {
      IAutomationVault.JobData memory _jobData = _jobsData[_i];

      // Necessary to avoid an empty job from being assigned to selectors
      if (_jobData.job != address(0)) {
        // Set the job for the relay
        if (_approvedJobs[_relay].add(_jobData.job)) {
          emit ApproveJob(_jobData.job);
        }

        // Get the array of selectors data
        SelectorData[] memory _selectorsData = _jobData.selectorsData;

        // Get the length of the selectors data array
        _selectorsLength = _selectorsData.length;

        // Set the selectors for the job
        for (_j = 0; _j < _selectorsLength;) {
          // Check if selector already exists if it does, skip it
          if (
            _approvedJobSelectorsWithHooks[_relay][_jobData.job][_selectorsData[_j].selector].selectorType
              == JobSelectorType.DISABLED
          ) {
            // Add the selector to the list of selectors
            _approvedJobSelectorsList[_relay][_jobData.job].push(_selectorsData[_j].selector);

            // Add the selector to the list of selectors with hooks
            _approvedJobSelectorsWithHooks[_relay][_jobData.job][_selectorsData[_j].selector] =
              _selectorsData[_j].hookData;

            // Emit the event
            emit ApproveJobSelector(
              _jobData.job,
              _selectorsData[_j].selector,
              _selectorsData[_j].hookData.selectorType,
              _selectorsData[_j].hookData.preHook,
              _selectorsData[_j].hookData.postHook
            );
          }

          unchecked {
            ++_j;
          }
        }
      }

      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IAutomationVault
  function deleteRelay(address _relay) external onlyOwner {
    if (_relay == address(0)) revert AutomationVault_RelayZero();

    // Remove the relay from the list of relays
    _relays.remove(_relay);

    // Create the counters variables
    uint256 _i;
    uint256 _j;

    // Get the approved callers
    address[] memory _callers = _approvedCallers[_relay].values();

    // Get the length of the approved callers array
    uint256 _valuesLength = _callers.length;

    // Remove the callers
    for (_i; _i < _valuesLength;) {
      _approvedCallers[_relay].remove(_callers[_i]);

      unchecked {
        ++_i;
      }
    }

    // Get the list of jobs
    address[] memory _jobs = _approvedJobs[_relay].values();

    // Get the length of the jobs array
    _valuesLength = _jobs.length;

    // Create the selector length variable
    bytes4[] memory _selectors;

    // Create the length variable
    uint256 _selectorsLength;

    // Remove the jobs
    for (_i = 0; _i < _valuesLength;) {
      _approvedJobs[_relay].remove(_jobs[_i]);

      // Get the length of the selectors array
      _selectorsLength = _approvedJobSelectorsList[_relay][_jobs[_i]].length;

      // Get the list of selectors
      _selectors = _approvedJobSelectorsList[_relay][_jobs[_i]];

      // Delete selectors list
      delete _approvedJobSelectorsList[_relay][_jobs[_i]];

      // Remove the selectors
      for (_j = 0; _j < _selectorsLength;) {
        delete _approvedJobSelectorsWithHooks[_relay][_jobs[_i]][bytes4(_selectors[_j])];

        unchecked {
          ++_j;
        }
      }

      unchecked {
        ++_i;
      }
    }

    // Emit the event
    emit DeleteRelay(_relay);
  }

  /// @inheritdoc IAutomationVault
  function modifyRelay(
    address _relay,
    address[] memory _callers,
    IAutomationVault.JobData[] memory _jobsData
  ) external onlyOwner {
    modifyRelayCallers(_relay, _callers);
    modifyRelayJobs(_relay, _jobsData);
  }

  /// @inheritdoc IAutomationVault
  function modifyRelayCallers(address _relay, address[] memory _callers) public onlyOwner {
    if (_relay == address(0)) revert AutomationVault_RelayZero();
    // Create the counter variable
    uint256 _i;

    // Get the approved callers
    address[] memory _oldApprovedCallers = _approvedCallers[_relay].values();

    // Get the length of the approved callers array
    uint256 _callersLength = _oldApprovedCallers.length;

    // Remove the callers
    for (_i; _i < _callersLength;) {
      _approvedCallers[_relay].remove(_oldApprovedCallers[_i]);

      unchecked {
        ++_i;
      }
    }

    // Get the length of the callers array
    _callersLength = _callers.length;

    // Set the callers for the relay
    for (_i = 0; _i < _callersLength;) {
      if (_approvedCallers[_relay].add(_callers[_i])) {
        emit ApproveRelayCaller(_relay, _callers[_i]);
      }

      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IAutomationVault
  function modifyRelayJobs(address _relay, IAutomationVault.JobData[] memory _jobsData) public onlyOwner {
    if (_relay == address(0)) revert AutomationVault_RelayZero();
    // Create the counters variables
    uint256 _i;
    uint256 _j;

    // Get the list of jobs
    address[] memory _jobs = _approvedJobs[_relay].values();

    // Get the length of the jobs array
    uint256 _jobsLength = _jobs.length;

    // Create the selector length variable
    bytes4[] memory _selectors;

    // Create the length variable
    uint256 _selectorsLength;

    // Remove the jobs
    for (_i; _i < _jobsLength;) {
      _approvedJobs[_relay].remove(_jobs[_i]);

      // Get the length of the selectors array
      _selectorsLength = _approvedJobSelectorsList[_relay][_jobs[_i]].length;

      // Get the list of selectors
      _selectors = _approvedJobSelectorsList[_relay][_jobs[_i]];

      // Delete selectors list
      delete _approvedJobSelectorsList[_relay][_jobs[_i]];

      // Remove the selectors
      for (_j = 0; _j < _selectorsLength;) {
        delete _approvedJobSelectorsWithHooks[_relay][_jobs[_i]][bytes4(_selectors[_j])];

        unchecked {
          ++_j;
        }
      }

      unchecked {
        ++_i;
      }
    }

    // Get the length of the jobs data array
    _jobsLength = _jobsData.length;

    // Set the jobs and their selectors for the relay
    for (_i = 0; _i < _jobsLength;) {
      IAutomationVault.JobData memory _jobData = _jobsData[_i];

      // Necessary to avoid an empty job from being assigned to selectors
      if (_jobData.job != address(0)) {
        // Set the job for the relay
        if (_approvedJobs[_relay].add(_jobData.job)) {
          emit ApproveJob(_jobData.job);
        }

        // Get the array of selectors data
        SelectorData[] memory _selectorsData = _jobData.selectorsData;

        // Get the length of the selectors data array
        _selectorsLength = _selectorsData.length;

        // Set the selectors for the job
        for (_j = 0; _j < _selectorsLength;) {
          if (
            _approvedJobSelectorsWithHooks[_relay][_jobData.job][_selectorsData[_j].selector].selectorType
              == JobSelectorType.DISABLED
          ) {
            // Add the selector to the list of selectors
            _approvedJobSelectorsList[_relay][_jobData.job].push(_selectorsData[_j].selector);

            // Add the selector to the list of selectors with hooks
            _approvedJobSelectorsWithHooks[_relay][_jobData.job][_selectorsData[_j].selector] =
              _selectorsData[_j].hookData;

            // Emit the event
            emit ApproveJobSelector(
              _jobData.job,
              _selectorsData[_j].selector,
              _selectorsData[_j].hookData.selectorType,
              _selectorsData[_j].hookData.preHook,
              _selectorsData[_j].hookData.postHook
            );
          }

          unchecked {
            ++_j;
          }
        }
      }

      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IAutomationVault
  function exec(address _relayCaller, ExecData[] calldata _execData, FeeData[] calldata _feeData) external {
    // Check that the specific caller is approved to call the relay
    if (!_approvedCallers[msg.sender].contains(_relayCaller) && !_approvedCallers[msg.sender].contains(_ALL)) {
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

      // Get the hook data
      HookData memory _hookData =
        _approvedJobSelectorsWithHooks[msg.sender][_dataToExecute.job][bytes4(_dataToExecute.jobData)];

      // Check that the selector is approved to be called
      if (_hookData.selectorType == JobSelectorType.DISABLED) {
        revert AutomationVault_NotApprovedJobSelector();
      }

      // If the selector type is enabled, execute the job
      if (_hookData.selectorType == JobSelectorType.ENABLED) {
        (_success,) = _dataToExecute.job.call(_dataToExecute.jobData);
        if (!_success) revert AutomationVault_ExecFailed();

        // Otherwise execute the pre hook and then the job
      } else if (
        _hookData.selectorType == JobSelectorType.ENABLED_WITH_PREHOOK
          || _hookData.selectorType == JobSelectorType.ENABLED_WITH_BOTHHOOKS
      ) {
        bytes memory _returnData;
        // Execute the pre hook and then the job if the pre hook is successful with the returned data
        (_success, _returnData) = _hookData.preHook.call(_dataToExecute.jobData);
        if (!_success) revert AutomationVault_ExecFailed();

        (_success,) = _dataToExecute.job.call(_returnData);
        if (!_success) revert AutomationVault_ExecFailed();
      }

      // If the selector type is enabled to execute the post hook, execute it
      if (
        _hookData.selectorType == JobSelectorType.ENABLED_WITH_POSTHOOK
          || _hookData.selectorType == JobSelectorType.ENABLED_WITH_BOTHHOOKS
      ) {
        // Execute the post hook and check if it was successful
        (_success,) = _hookData.postHook.call('');
        if (!_success) revert AutomationVault_ExecFailed();
      }

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
      if (_feeInfo.feeToken == NATIVE_TOKEN) {
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
