// SPDX-License-Identifier: MIT
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
   * @notice Emitted when a relay caller is approved
   * @param  _relay The address of the relay
   * @param  _caller The address of the caller
   */
  event ApproveRelayCaller(address indexed _relay, address indexed _caller);

  /**
   * @notice Emitted when a relay is revoked
   * @param  _relay The address of the relay
   */
  event RevokeRelay(address indexed _relay);

  /**
   * @notice Emitted when a relay caller is revoked
   * @param  _relay The address of the relay
   * @param  _caller The address of the caller
   */
  event RevokeRelayCaller(address indexed _relay, address indexed _caller);

  /**
   * @notice Emitted when job is approved
   * @param  _job The address of the job
   */
  event ApproveJob(address indexed _job);

  /**
   * @notice Emitted when job selector is approved
   * @param  _job The address of the job
   * @param  _functionSelector The function selector
   */
  event ApproveJobSelector(address indexed _job, bytes4 indexed _functionSelector);

  /**
   * @notice Emitted when job is revoked
   * @param  _job The address of the job
   */
  event RevokeJob(address indexed _job);

  /**
   * @notice Emitted when job selector is revoked
   * @param  _job The address of the job
   * @param  _functionSelector The function selector
   */
  event RevokeJobSelector(address indexed _job, bytes4 indexed _functionSelector);

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
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

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

  function nativeToken() external view returns (address _nativeToken);

  /**
   * @notice Returns the pending owner address
   * @return _pendingOwner The address of the pending owner
   */
  function pendingOwner() external view returns (address _pendingOwner);

  /**
   * @notice Returns the approved relay callers for a specific relay
   * @param  _relay The address of the relay
   * @return _enabledCallers The array of approved relay callers
   */
  function relayEnabledCallers(address _relay) external view returns (address[] memory _enabledCallers);

  /**
   * @notice Returns the approved job selectors for a specific job
   * @param  _job The address of the job
   * @return _enabledSelectors The array of approved job selectors
   */
  function jobEnabledSelectors(address _job) external view returns (bytes32[] memory _enabledSelectors);

  /**
   * @notice Returns the approved relays
   * @return __relays The array of approved relays
   */
  function relays() external view returns (address[] memory __relays);

  /**
   * @notice Returns the approved jobs
   * @return __jobs The array of approved jobs
   */
  function jobs() external view returns (address[] memory __jobs);

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
   * @notice Approves relay callers which will be able to call a relay to execute jobs
   * @param  _relay The address of the relay
   * @param  _callers The array of callers
   */
  function approveRelayCallers(address _relay, address[] calldata _callers) external;

  /**
   * @notice Revokes relay callers which will not be able to call a relay to execute jobs
   * @param  _relay The address of the relay
   * @param  _callers The array of callers
   */
  function revokeRelayCallers(address _relay, address[] calldata _callers) external;

  /**
   * @notice Approves job selectors which could be called to execute the job
   * @param  _job The address of the job
   * @param  _functionSelectors The array of function selectors
   */
  function approveJobSelectors(address _job, bytes4[] calldata _functionSelectors) external;

  /**
   * @notice Revokes job selectors which could not be called to execute the job
   * @param  _job The address of the job
   * @param  _functionSelectors The array of function selectors
   */
  function revokeJobSelectors(address _job, bytes4[] calldata _functionSelectors) external;

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
