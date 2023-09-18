// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IAutomationVault {
  /// EVENTS ///
  event ChangeOwner(address indexed _pendingOwner);
  event AcceptOwner(address indexed _owner);
  event WithdrawFunds(address indexed _token, uint256 _amount, address indexed _receiver);
  event ApproveRelay(address indexed _relay);
  event ApproveRelayCaller(address indexed _relay, address indexed _caller);
  event RevokeRelay(address indexed _relay);
  event RevokeRelayCaller(address indexed _relay, address indexed _caller);
  event ApproveJob(address indexed _job);
  event ApproveJobFunction(address indexed _job, bytes4 indexed _functionSelector);
  event RevokeJob(address indexed _job);
  event RevokeJobFunction(address indexed _job, bytes4 indexed _functionSelector);
  event JobExecuted(address indexed _relay, address indexed _relayCaller, address indexed _job, bytes _jobData);
  event IssuePayment(
    address indexed _relay, address indexed _relayCaller, address indexed _feeRecipient, address _feeToken, uint256 _fee
  );

  /// ERRORS ///
  error AutomationVault_ETHTransferFailed();
  error AutomationVault_NotApprovedRelayCaller();
  error AutomationVault_NotApprovedJobFunction();
  error AutomationVault_ExecFailed();
  error AutomationVault_OnlyOwner(address _owner);
  error AutomationVault_OnlyPendingOwner(address _pendingOwner);

  /// STRUCTS ///
  struct ExecData {
    address job;
    bytes jobData;
  }

  struct FeeData {
    address feeRecipient;
    address feeToken;
    uint256 fee;
  }

  /// VIEW FUNCTIONS ///
  function owner() external view returns (address _owner);

  function pendingOwner() external view returns (address _pendingOwner);

  function organizationName() external view returns (string calldata _organizationName);

  function relayEnabledCallers(address _relay) external view returns (address[] memory _enabledCallers);

  function jobEnabledFunctions(address _job) external view returns (bytes32[] memory _enabledSelectors);

  function relays() external view returns (address[] memory __relays);

  function jobs() external view returns (address[] memory __jobs);

  /// EXTERNAL FUNCTIONS ///
  function changeOwner(address _pendingOwner) external;

  function acceptOwner() external;

  function withdrawFunds(address _token, uint256 _amount, address _receiver) external payable;

  function approveRelayCallers(address _relay, address[] calldata _callers) external;

  function revokeRelayCallers(address _relay, address[] calldata _callers) external;

  function approveJobFunctions(address _job, bytes4[] calldata _functionSelectors) external;

  function revokeJobFunctions(address _job, bytes4[] calldata _functionSelectors) external;

  function exec(address _relayCaller, ExecData[] calldata _execData, FeeData[] calldata _feeData) external payable;
}
