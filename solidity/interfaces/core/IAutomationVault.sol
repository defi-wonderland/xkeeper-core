// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IAutomationVault {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the owner is proposed to change
   * @param  _pendingOwner The address that is being proposed
   */
  event ChangeOwner(address indexed _pendingOwner);

  /**
   * @notice Emitted when the owner is accepted
   * @param  _owner The address of the new owner
   */
  event AcceptOwner(address indexed _owner);

  /**
   * @notice Emitted when funds are withdrawn
   * @param  _token The address of the token
   * @param  _amount The amount of tokens
   * @param  _receiver The address of the receiver
   */
  event WithdrawFunds(address indexed _token, uint256 _amount, address indexed _receiver);

  /**
   * @notice Emitted when a relay is approved
   * @param  _relay The address of the relay
   */
  event ApproveRelay(address indexed _relay);

  /**
   * @notice Emitted when a relay is deleted
   * @param  _relay The address of the relay
   */
  event DeleteRelay(address indexed _relay);

  /**
   * @notice Emitted when a relay caller is approved
   * @param  _relay The address of the relay
   * @param  _caller The address of the caller
   */
  event ApproveRelayCaller(address indexed _relay, address indexed _caller);

  /**
   * @notice Emitted when job is approved
   * @param  _job The address of the job
   */
  event ApproveJob(address indexed _job);

  /**
   * @notice Emitted when job selector is approved
   * @param  _job The address of the job
   * @param  _functionSelector The function selector
   * @param  _selectorType The type of the job selector
   * @param  _preHook The address of the prehook
   * @param  _postHook The address of the posthook
   */
  event ApproveJobSelector(
    address indexed _job,
    bytes4 indexed _functionSelector,
    JobSelectorType _selectorType,
    address _preHook,
    address _postHook
  );

  /**
   * @notice Emitted when a job is executed
   * @param  _relay The relay address
   * @param  _relayCaller The relay caller address
   * @param  _job The address of the job
   * @param  _jobData The data to execute the job
   */
  event JobExecuted(address indexed _relay, address indexed _relayCaller, address indexed _job, bytes _jobData);

  /**
   * @notice Emitted when a payment is issued
   * @param  _relay The relay address
   * @param  _relayCaller The relay caller address
   * @param  _feeRecipient The recipient address which will receive the fee
   * @param  _feeToken The address of the token
   * @param  _fee The amount of tokens
   */
  event IssuePayment(
    address indexed _relay, address indexed _relayCaller, address indexed _feeRecipient, address _feeToken, uint256 _fee
  );

  /**
   * @notice Emitted when native token is received in the automation vault
   * @param  _sender The sender address
   * @param  _amount The amount of native token
   */
  event NativeTokenReceived(address indexed _sender, uint256 _amount);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the the relay is the zero address
   */
  error AutomationVault_RelayZero();

  /**
   * @notice Thrown when the relay is already approved
   */
  error AutomationVault_RelayAlreadyApproved();

  /**
   * @notice Thrown when ether transfer fails
   */
  error AutomationVault_NativeTokenTransferFailed();

  /**
   * @notice Thrown when a not approved relay caller is trying to execute a job
   */
  error AutomationVault_NotApprovedRelayCaller();

  /**
   * @notice Thrown when a not approved job selector is trying to be executed
   */
  error AutomationVault_NotApprovedJobSelector();

  /**
   * @notice Thrown when a job execution fails
   */
  error AutomationVault_ExecFailed();

  /**
   * @notice Thrown when the caller is not the owner
   */
  error AutomationVault_OnlyOwner();

  /**
   * @notice Thrown when the caller is not the pending owner
   */
  error AutomationVault_OnlyPendingOwner();

  /*///////////////////////////////////////////////////////////////
                              ENUMS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The type of the job selector
   * @param DISABLED The job selector is disabled
   * @param ENABLED The job selector is enabled
   * @param ENABLED_WITH_PREHOOK The job selector is enabled with a prehook
   * @param ENABLED_WITH_POSTHOOK The job selector is enabled with a posthook
   * @param ENABLED_WITH_BOTHHOOKS The job selector is enabled with both hooks
   */
  enum JobSelectorType {
    DISABLED,
    ENABLED,
    ENABLED_WITH_PREHOOK,
    ENABLED_WITH_POSTHOOK,
    ENABLED_WITH_BOTHHOOKS
  }

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The data to execute a hook
   * @param selectorType The type of the job selector
   * @param preHook The address of the prehook
   * @param postHook The address of the posthook
   */
  struct HookData {
    JobSelectorType selectorType;
    address preHook;
    address postHook;
  }

  /**
   * @notice The data to execute a job selector
   * @param selector The function selector
   * @param hookData The hook data
   */
  struct SelectorData {
    bytes4 selector;
    HookData hookData;
  }

  /**
   * @notice The data to execute a job
   * @param job The address of the job
   * @param jobData The data to execute the job
   */
  struct ExecData {
    address job;
    bytes jobData;
  }

  /**
   * @notice The data to issue a payment
   * @param feeRecipient The recipient address which will receive the fee
   * @param feeToken The address of the token
   * @param fee The amount of tokens
   */
  struct FeeData {
    address feeRecipient;
    address feeToken;
    uint256 fee;
  }

  /**
   * @notice The data of a job
   * @param job The address of the job
   * @param selectorsData The array of job selectors data
   */
  struct JobData {
    address job;
    SelectorData[] selectorsData;
  }

  /*///////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the owner address
   * @return _owner The address of the owner
   */
  function owner() external view returns (address _owner);

  /**
   * @notice Returns the address of the native token
   * @return _nativeToken The address of the native token
   */
  function NATIVE_TOKEN() external view returns (address _nativeToken);

  /**
   * @notice Returns the pending owner address
   * @return _pendingOwner The address of the pending owner
   */
  function pendingOwner() external view returns (address _pendingOwner);

  /**
   * @notice Returns the approved relay callers and selectors for a specific relay and job
   * @param  _relay The address of the relay
   * @return _callers The array of approved relay callers
   * @return _jobsData The array of approved jobs and selectors
   */
  function getRelayData(address _relay)
    external
    returns (address[] memory _callers, IAutomationVault.JobData[] memory _jobsData);

  /**
   * @notice Returns the approved relays
   * @return _listRelays The array of approved relays
   */
  function relays() external view returns (address[] memory _listRelays);

  /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Propose a new owner for the contract
   * @dev    The new owner will need to accept the ownership before it is transferred
   * @param  _pendingOwner The address of the new owner
   */
  function changeOwner(address _pendingOwner) external;

  /**
   * @notice Accepts the ownership of the contract
   */
  function acceptOwner() external;

  /**
   * @notice Withdraws funds deposited in the contract
   * @dev    Only the owner can call this function
   * @param  _token The address of the token
   * @param  _amount The amount of tokens
   * @param  _receiver The address of the receiver
   */
  function withdrawFunds(address _token, uint256 _amount, address _receiver) external;

  /**
   * @notice Add a new relay to the automation vault with the desired callers, jobs and selectors
   * @dev    If the relay is valid, it can be passed with all the fields or only the necessary ones, passing the empty argument in the unwanted ones
   * @param  _relay The address of the relay
   * @param  _callers The array of callers
   * @param _jobsData The array of job data
   */
  function addRelay(
    address _relay,
    address[] calldata _callers,
    IAutomationVault.JobData[] calldata _jobsData
  ) external;

  /**
   * @notice Revokes the approval of a specific relay
   * @dev    The callers, jobs and selectors will be deleted
   * @param  _relay The address of the relay
   */
  function deleteRelay(address _relay) external;

  /**
   * @notice Modify the callers, jobs and selectors of a specific relay
   * @dev    If any of the arguments is empty, the data will be deleted
   * @param  _relay The address of the relay
   * @param  _callers The array of callers
   * @param _jobsData The array of job data
   */
  function modifyRelay(
    address _relay,
    address[] calldata _callers,
    IAutomationVault.JobData[] calldata _jobsData
  ) external;

  /**
   * @notice Modify the callers of a specific relay
   * @dev    If the array is empty, the data will be deleted
   * @param  _relay The address of the relay
   * @param  _callers The array of callers
   */
  function modifyRelayCallers(address _relay, address[] calldata _callers) external;

  /**
   * @notice Modify the jobs and selectors of a specific relay
   * @dev    If the array is empty, the data will be deleted, also if the function selectors array is empty
   * @param  _relay The address of the relay
   * @param _jobsData The array of job data
   */
  function modifyRelayJobs(address _relay, IAutomationVault.JobData[] calldata _jobsData) external;

  /**
   * @notice Executes a job and issues a payment to the fee data receivers
   * @dev    The function can be called with only execData, only feeData or both. The strategy of the payment
   *         will be different depending on which relay is calling the function
   * @param  _relayCaller The address of the relay caller
   * @param  _execData The array of exec data
   * @param  _feeData The array of fee data
   */
  function exec(address _relayCaller, ExecData[] calldata _execData, FeeData[] calldata _feeData) external;
}
