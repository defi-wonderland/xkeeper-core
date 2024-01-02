/// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {AutomationVault, IAutomationVault, EnumerableSet, IERC20} from '@contracts/AutomationVault.sol';
import {_ETH, _ALL} from '@utils/Constants.sol';

contract AutomationVaultForTest is AutomationVault {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(address _owner, address _nativeToken) AutomationVault(_owner, _nativeToken) {}

  function setPendingOwnerForTest(address _pendingOwner) public {
    pendingOwner = _pendingOwner;
  }

  function addRelayEnabledCallersForTest(address _relay, address _relayCaller) public {
    _relayCallers[_relay].add(_relayCaller);
    _relays.add(_relay);
  }

  function addJobEnabledSelectorsForTest(address _relay, address _job, bytes4 _functionSelector) public {
    _relayJobSelectors[_relay][_job].add(_functionSelector);
    _jobs.add(_job);
  }

  function removeJobEnabledSelectorsForTest(address _relay, address _job, bytes4 _functionSelector) public {
    _relayJobSelectors[_relay][_job].remove(_functionSelector);
  }
}

contract NoFallbackForTest {}

/**
 * @title AutomationVault Unit tests
 */
abstract contract AutomationVaultUnitTest is Test {
  /// Events
  event ChangeOwner(address indexed _pendingOwner);
  event AcceptOwner(address indexed _owner);
  event DepositFunds(address indexed _token, uint256 _amount);
  event WithdrawFunds(address indexed _token, uint256 _amount, address indexed _receiver);
  event ApproveRelay(address indexed _relay);
  event ApproveRelayCaller(address indexed _relay, address indexed _caller);
  event RevokeRelay(address indexed _relay);
  event RevokeRelayCaller(address indexed _relay, address indexed _caller);
  event ApproveJob(address indexed _job);
  event ApproveJobSelector(address indexed _job, bytes4 indexed _functionSelector);
  event RevokeJob(address indexed _job);
  event RevokeJobSelector(address indexed _job, bytes4 indexed _functionSelector);
  event JobExecuted(address indexed _relay, address indexed _relayCaller, address indexed _job, bytes _jobData);
  event IssuePayment(
    address indexed _relay, address indexed _relayCaller, address indexed _feeRecipient, address _feeToken, uint256 _fee
  );

  /// AutomationVault contract
  AutomationVaultForTest public automationVault;

  /// Mock contracts
  address public token;
  address public job;
  address public relay;
  address public relayCaller;

  /// EOAs
  address public owner;
  address public pendingOwner;
  address public receiver;

  /// Data
  bytes4 public jobSelector;
  bytes public jobData;

  function setUp() public virtual {
    jobSelector = bytes4(keccak256('jobSelector()'));
    jobData = abi.encodeWithSelector(jobSelector, owner);

    owner = makeAddr('Owner');
    pendingOwner = makeAddr('PendingOwner');
    receiver = makeAddr('Receiver');

    token = makeAddr('Token');
    job = makeAddr('Job');
    relay = makeAddr('Relay');
    relayCaller = makeAddr('RelayCaller');

    automationVault = new AutomationVaultForTest(owner, _ETH);
  }
}

contract UnitAutomationVaultConstructor is AutomationVaultUnitTest {
  /**
   * @notice Check that the constructor sets the params correctly
   */
  function testParamsAreSet() public {
    assertEq(automationVault.owner(), owner);
    assertEq(automationVault.NATIVE_TOKEN(), _ETH);
  }
}

contract UnitGetRelayData is AutomationVaultUnitTest {
  /**
   * @notice Check that the relay data is correct
   */
  function testRelayData(address _relay, address _relayCaller, address _job, bytes4 _functionSelector) public {
    automationVault.addRelayEnabledCallersForTest(_relay, _relayCaller);
    automationVault.addJobEnabledSelectorsForTest(_relay, _job, _functionSelector);

    (address[] memory _callers, bytes32[] memory _selectors) = automationVault.getRelayData(_relay, _job);

    assertEq(_callers.length, 1);
    assertEq(_callers[0], _relayCaller);

    assertEq(_selectors.length, 1);
    assertEq(_selectors[0], _functionSelector);
  }
}

contract UnitAutomationVaultListRelays is AutomationVaultUnitTest {
  /**
   * @notice Check that the relays length is correct
   */
  function testRelaysLength(address _relay) public {
    automationVault.addRelayEnabledCallersForTest(_relay, owner);

    assertEq(automationVault.relays().length, 1);
  }
}

contract UnitAutomationVaultListJobs is AutomationVaultUnitTest {
  /**
   * @notice Check that the jobs length is correct
   */
  function testJobLength(address _relay, address _job) public {
    automationVault.addJobEnabledSelectorsForTest(_relay, _job, jobSelector);

    assertEq(automationVault.jobs().length, 1);
  }
}

contract UnitAutomationVaultChangeOwner is AutomationVaultUnitTest {
  function setUp() public override {
    AutomationVaultUnitTest.setUp();

    vm.startPrank(owner);
  }

  /**
   * @notice Checks that the test has to revert if the caller is not the owner
   */
  function testRevertIfCallerIsNotOwner() public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector));

    changePrank(pendingOwner);
    automationVault.changeOwner(pendingOwner);
  }

  /**
   * @notice Check that the pending owner is set correctly
   */
  function testSetPendingOwner() public {
    automationVault.changeOwner(pendingOwner);

    assertEq(automationVault.pendingOwner(), pendingOwner);
  }

  /**
   * @notice  Emit ChangeOwner event when the pending owner is set
   */
  function testEmitChangeOwner() public {
    vm.expectEmit();
    emit ChangeOwner(pendingOwner);

    automationVault.changeOwner(pendingOwner);
  }
}

contract UnitAutomationVaultAcceptOwner is AutomationVaultUnitTest {
  function setUp() public override {
    AutomationVaultUnitTest.setUp();

    automationVault.setPendingOwnerForTest(pendingOwner);

    vm.startPrank(pendingOwner);
  }

  /**
   * @notice Check that the test has to revert if the caller is not the pending owner
   */
  function testRevertIfCallerIsNotPendingOwner() public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyPendingOwner.selector));

    changePrank(owner);
    automationVault.acceptOwner();
  }

  /**
   * @notice Check that the pending owner accepts the ownership
   */
  function testSetJobOwner() public {
    automationVault.acceptOwner();

    assertEq(automationVault.owner(), pendingOwner);
  }

  /**
   * @notice Check that the pending owner is set to zero
   */
  function testDeletePendingOwner() public {
    automationVault.acceptOwner();

    assertEq(automationVault.pendingOwner(), address(0));
  }

  /**
   * @notice Emit AcceptOwner event when the pending owner accepts the ownership
   */
  function testEmitAcceptOwner() public {
    vm.expectEmit();
    emit AcceptOwner(pendingOwner);

    automationVault.acceptOwner();
  }
}

contract UnitAutomationVaultWithdrawFunds is AutomationVaultUnitTest {
  uint256 internal _balance;
  IERC20 internal _token;

  modifier happyPath(uint128 _amount) {
    vm.assume(_amount > 0);

    /// Add balance to the contract
    vm.deal(address(automationVault), 2 ** 128 - 1);

    /// Mock the token transfer and balanceOf
    _token = IERC20(token);
    vm.mockCall(token, abi.encodeWithSelector(IERC20.transfer.selector, receiver, _amount), abi.encode(true));
    vm.mockCall(token, abi.encodeWithSelector(IERC20.balanceOf.selector, receiver), abi.encode(_amount));

    _balance = address(automationVault).balance;
    vm.startPrank(owner);
    _;
  }

  /**
   * @notice Checks that the test has to revert if the caller is not the owner
   */
  function testRevertIfCallerIsNotOwner(uint128 _amount) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector));

    automationVault.withdrawFunds(_ETH, _amount, owner);
  }

  /**
   * @notice Checks that the test has to revert if the native token transfer failed
   */
  function testRevertIfNativeTokenTransferFailed() public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_NativeTokenTransferFailed.selector));

    vm.prank(owner);
    automationVault.withdrawFunds(_ETH, type(uint160).max, address(automationVault));
  }

  /**
   * @notice Checks that the balances are updated correctly
   */
  function testWithdrawNativeTokenAmountUpdateBalances(uint128 _amount) public happyPath(_amount) {
    automationVault.withdrawFunds(_ETH, _amount, receiver);

    assertEq(receiver.balance, _amount);
    assertEq(address(automationVault).balance, _balance - _amount);
  }

  /**
   * @notice Checks that the balances are updated correctly
   */
  function testWithdrawERC20AmountUpdateBalances(uint128 _amount) public happyPath(_amount) {
    automationVault.withdrawFunds(token, _amount, receiver);

    assertEq(_token.balanceOf(receiver), _amount);
  }

  /**
   * @notice Emit WithdrawFunds event when the native token is withdrawn
   */
  function testEmitWithdrawNativeTokenAmount(uint128 _amount) public happyPath(_amount) {
    vm.expectEmit();
    emit WithdrawFunds(_ETH, _amount, receiver);

    automationVault.withdrawFunds(_ETH, _amount, receiver);
  }

  /**
   * @notice Emit WithdrawFunds event when the token ERC20 is withdrawn
   */
  function testEmitWithdrawERC2OAmount(uint128 _amount) public happyPath(_amount) {
    vm.expectEmit();
    emit WithdrawFunds(token, _amount, receiver);

    automationVault.withdrawFunds(token, _amount, receiver);
  }
}

/**
 * @dev Is not possible to create in the happy path type struct IAutomationVault.JobData memory[] memory to storage because is not yet supported.
 */
contract UnitAutomationVaultApproveRelayData is AutomationVaultUnitTest {
  address[] internal _callers;
  bytes4[] internal _functionSelectors;

  modifier happyPath(address _relay, address _job, bytes4 _functionSelector) {
    /// @dev This is a workaround for the fact that the VM does not support dynamic arrays
    vm.assume(_relay != address(0));
    vm.assume(_job != address(0));
    vm.assume(_functionSelector != jobSelector);

    /// Create the data
    _callers = new address[](2);

    _callers[0] = (owner);
    _callers[1] = (pendingOwner);

    _functionSelectors = new bytes4[](2);

    _functionSelectors[0] = jobSelector;
    _functionSelectors[1] = _functionSelector;

    vm.startPrank(owner);
    _;
  }

  /**
   * @notice Checks that the test has to revert if the caller is not the owner
   */
  function testRevertIfCallerIsNotOwner(address _relay, IAutomationVault.JobData[] memory _jobsData) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector));

    vm.prank(pendingOwner);
    automationVault.approveRelayData(_relay, _callers, _jobsData);
  }

  /**
   * @notice Checks that the test has to revert if the relay address is zero
   */
  function testRevertIfRelayIsZero(IAutomationVault.JobData[] memory _jobsData) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_RelayZero.selector));

    vm.prank(owner);
    automationVault.approveRelayData(address(0), _callers, _jobsData);
  }

  /**
   * @notice Emit ApproveRelay event when the relay is approved
   */
  function testEmitApproveRelay(
    address _relay,
    address _job,
    bytes4 _functionSelector
  ) public happyPath(_relay, _job, _functionSelector) {
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _functionSelectors;

    vm.expectEmit();
    emit ApproveRelay(_relay);

    automationVault.approveRelayData(_relay, _callers, _jobsData);
  }

  /**
   * @notice Emit ApproveRelayCaller event when the relay caller is approved
   */
  function testEmitApproveCaller(
    address _relay,
    address _job,
    bytes4 _functionSelector
  ) public happyPath(_relay, _job, _functionSelector) {
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _functionSelectors;

    for (uint256 _i; _i < _callers.length; _i++) {
      vm.expectEmit();
      emit ApproveRelayCaller(_relay, _callers[_i]);
    }

    automationVault.approveRelayData(_relay, _callers, _jobsData);
  }

  /**
   * @notice Emit ApproveJob event when the job is approved
   */
  function testEmitApproveJob(
    address _relay,
    address _job,
    bytes4 _functionSelector
  ) public happyPath(_relay, _job, _functionSelector) {
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _functionSelectors;

    vm.expectEmit();
    emit ApproveJob(_job);

    automationVault.approveRelayData(_relay, _callers, _jobsData);
  }

  /**
   * @notice Emit ApproveJobSelector event when the job selector is approved
   */
  function testEmitApproveFunctionSelector(
    address _relay,
    address _job,
    bytes4 _functionSelector
  ) public happyPath(_relay, _job, _functionSelector) {
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _functionSelectors;

    for (uint256 _i; _i < _functionSelectors.length; _i++) {
      vm.expectEmit();
      emit ApproveJobSelector(_job, _functionSelectors[_i]);
    }

    automationVault.approveRelayData(_relay, _callers, _jobsData);
  }
}

/**
 * @dev Is not possible to create in the happy path type struct IAutomationVault.JobData memory[] memory to storage because is not yet supported.
 */
contract UnitAutomationVaultRevokeRelayData is AutomationVaultUnitTest {
  address[] internal _callers;
  bytes4[] internal _functionSelectors;

  modifier happyPath(address _relay, address _job, bytes4 _functionSelector) {
    /// @dev This is a workaround for the fact that the VM does not support dynamic arrays
    vm.assume(_relay != address(0));
    vm.assume(_job != address(0));
    vm.assume(_functionSelector != jobSelector);

    /// Create the data
    _callers = new address[](2);

    _callers[0] = (owner);
    _callers[1] = (pendingOwner);

    _functionSelectors = new bytes4[](2);

    _functionSelectors[0] = jobSelector;
    _functionSelectors[1] = _functionSelector;

    automationVault.addRelayEnabledCallersForTest(_relay, owner);
    automationVault.addRelayEnabledCallersForTest(_relay, pendingOwner);

    automationVault.addJobEnabledSelectorsForTest(_relay, _job, jobSelector);
    automationVault.addJobEnabledSelectorsForTest(_relay, _job, _functionSelector);

    vm.startPrank(owner);
    _;
  }

  /**
   * @notice Checks that the test has to revert if the caller is not the owner
   */
  function testRevertIfCallerIsNotOwner(address _relay, IAutomationVault.JobData[] memory _jobsData) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector));

    vm.prank(pendingOwner);
    automationVault.revokeRelayData(_relay, _callers, _jobsData);
  }

  /**
   * @notice Checks that the test has to revert if the relay address is zero
   */
  function testRevertIfRelayIsZero(IAutomationVault.JobData[] memory _jobsData) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_RelayZero.selector));

    vm.prank(owner);
    automationVault.revokeRelayData(address(0), _callers, _jobsData);
  }

  /**
   * @notice Emit RevokeRelay event when the relay is revoked
   */
  function testEmitRevokeRelay(
    address _relay,
    address _job,
    bytes4 _functionSelector
  ) public happyPath(_relay, _job, _functionSelector) {
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _functionSelectors;

    vm.expectEmit();
    emit RevokeRelay(_relay);

    automationVault.revokeRelayData(_relay, _callers, _jobsData);
  }

  /**
   * @notice Emit RevokeRelayCaller event when the relay caller is revoked
   */
  function testEmitRevokeCaller(
    address _relay,
    address _job,
    bytes4 _functionSelector
  ) public happyPath(_relay, _job, _functionSelector) {
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _functionSelectors;

    for (uint256 _i; _i < _callers.length; _i++) {
      vm.expectEmit();
      emit RevokeRelayCaller(_relay, _callers[_i]);
    }

    automationVault.revokeRelayData(_relay, _callers, _jobsData);
  }

  /**
   * @notice Emit RevokeJob event when the job is revoked
   */
  function testEmitRevokeJob(
    address _relay,
    address _job,
    bytes4 _functionSelector
  ) public happyPath(_relay, _job, _functionSelector) {
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _functionSelectors;

    vm.expectEmit();
    emit RevokeJob(_job);

    automationVault.revokeRelayData(_relay, _callers, _jobsData);
  }

  /**
   * @notice Emit RevokeJobSelector event when the job selector is revoked
   */
  function testEmitRevokeFunctionSelector(
    address _relay,
    address _job,
    bytes4 _functionSelector
  ) public happyPath(_relay, _job, _functionSelector) {
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _functionSelectors;

    for (uint256 _i; _i < _functionSelectors.length; _i++) {
      vm.expectEmit();
      emit RevokeJobSelector(_job, _functionSelectors[_i]);
    }

    automationVault.revokeRelayData(_relay, _callers, _jobsData);
  }
}

contract UnitAutomationVaultExec is AutomationVaultUnitTest {
  modifier happyPath(IAutomationVault.ExecData[] memory _execData, IAutomationVault.FeeData[] memory _feeData) {
    vm.assume(_execData.length < 30 && _feeData.length < 30);

    automationVault.addRelayEnabledCallersForTest(relay, relayCaller);

    for (uint256 _i; _i < _execData.length; ++_i) {
      automationVault.addJobEnabledSelectorsForTest(relay, _execData[_i].job, bytes4(_execData[_i].jobData));
      assumeNoPrecompiles(_execData[_i].job);
      vm.assume(_execData[_i].job != address(vm));
      vm.mockCall(_execData[_i].job, abi.encodeWithSelector(bytes4(_execData[_i].jobData)), abi.encode());
    }

    for (uint256 _i; _i < _feeData.length; ++_i) {
      assumeNoPrecompiles(_feeData[_i].feeRecipient);
      assumePayable(_feeData[_i].feeRecipient);
      assumeNoPrecompiles(_feeData[_i].feeToken);
      vm.assume(_feeData[_i].feeToken != address(vm));
      vm.mockCall(_feeData[_i].feeToken, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    }

    deal(address(automationVault), type(uint256).max);

    vm.startPrank(relay);
    _;
  }

  /**
   * @notice Checks that the test has to revert if the caller is not the relay caller
   */
  function testRevertIfNotApprovedRelayCaller(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_execData, _feeData) {
    vm.expectRevert(IAutomationVault.AutomationVault_NotApprovedRelayCaller.selector);

    changePrank(owner);
    automationVault.exec(relayCaller, _execData, _feeData);
  }

  //   function testRevertIfNotApprovedJobSelector(
  //     IAutomationVault.ExecData[] memory _execData,
  //     IAutomationVault.FeeData[] memory _feeData
  //   ) public happyPath(_execData, _feeData) {
  //     vm.assume(_execData.length > 3);
  //     automationVault.removeJobEnabledSelectorsForTest(_execData[1].job, bytes4(_execData[1].jobData));

  //     vm.expectRevert(IAutomationVault.AutomationVault_NotApprovedJobSelector.selector);

  //     automationVault.exec(relayCaller, _execData, _feeData);
  //   }

  /**
   * @notice Checks that the test has to revert if the job call failed
   */
  function testRevertIfJobCallFailed(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_execData, _feeData) {
    vm.assume(_execData.length > 3);
    vm.etch(_execData[1].job, type(NoFallbackForTest).runtimeCode);
    vm.mockCallRevert(_execData[1].job, abi.encodeWithSelector(bytes4(_execData[1].jobData)), abi.encode());

    vm.expectRevert(IAutomationVault.AutomationVault_ExecFailed.selector);

    automationVault.exec(relayCaller, _execData, _feeData);
  }

  /**
   * @notice Checks that call is executed correctly without fees
   */
  function testCallOnlyJobFunction(IAutomationVault.ExecData[] memory _execData)
    public
    happyPath(_execData, new IAutomationVault.FeeData[](0))
  {
    vm.assume(_execData.length > 3);
    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](0);

    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.expectCall(_execData[_i].job, _execData[_i].jobData, 1);
    }

    automationVault.exec(relayCaller, _execData, _feeData);
  }

  /**
   * @notice Checks that call is executed correctly with fees
   */
  function testCallJobFunction(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_execData, _feeData) {
    vm.assume(_execData.length > 3);

    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.expectCall(_execData[_i].job, _execData[_i].jobData, 1);
    }

    automationVault.exec(relayCaller, _execData, _feeData);
  }

  /**
   * @notice Checks that call is executed correctly with fees and open sender
   */
  function testCallJobFunctionWithOpenSender(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData,
    address _sender
  ) public happyPath(_execData, _feeData) {
    vm.assume(_execData.length > 3);
    automationVault.addRelayEnabledCallersForTest(relay, _ALL);

    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.expectCall(_execData[_i].job, _execData[_i].jobData, 1);
    }

    automationVault.exec(_sender, _execData, _feeData);
  }

  /**
   * @notice Emit JobExecuted event when the job is executed
   */
  function testEmitJobExecuted(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_execData, _feeData) {
    vm.assume(_execData.length > 3);

    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.expectEmit();
      emit JobExecuted(relay, relayCaller, _execData[_i].job, _execData[_i].jobData);
    }

    automationVault.exec(relayCaller, _execData, _feeData);
  }

  /**
   * @notice Checks that the test has to revert if the native token transfer failed
   */
  function testRevertIfNativeTokenTransferFailed(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_execData, _feeData) {
    vm.assume(_feeData.length > 3);
    _feeData[1].feeToken = _ETH;
    vm.etch(_feeData[1].feeRecipient, type(NoFallbackForTest).runtimeCode);

    vm.expectRevert(IAutomationVault.AutomationVault_NativeTokenTransferFailed.selector);

    automationVault.exec(relayCaller, _execData, _feeData);
  }

  /**
   * @notice Checks that native token transfer is executed correctly
   */
  function testCallNativeTokenTransfer(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData,
    uint128 _fee
  ) public happyPath(_execData, _feeData) {
    vm.assume(_feeData.length > 3);
    for (uint256 _i; _i < _feeData.length; ++_i) {
      _feeData[_i].feeToken = _ETH;
      _feeData[_i].fee = _fee;
    }

    automationVault.exec(relayCaller, _execData, _feeData);

    for (uint256 _i; _i < _feeData.length; ++_i) {
      assertGe(_feeData[_i].feeRecipient.balance, _feeData[_i].fee);
    }
  }

  /**
   * @notice Checks that token transfer is executed correctly
   */
  function testCallTokenTransfer(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_execData, _feeData) {
    vm.assume(_feeData.length > 3);
    for (uint256 _i; _i < _feeData.length; ++_i) {
      vm.assume(_feeData[_i].feeToken != _ETH);
    }

    for (uint256 _i; _i < _feeData.length; ++_i) {
      vm.expectCall(
        _feeData[_i].feeToken, abi.encodeCall(IERC20.transfer, (_feeData[_i].feeRecipient, _feeData[_i].fee)), 1
      );
    }

    automationVault.exec(relayCaller, _execData, _feeData);
  }

  /**
   * @notice Emit IssuePayment event when the payment is issued
   */
  function testEmitIssuePayment(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_execData, _feeData) {
    vm.assume(_feeData.length > 3);

    for (uint256 _i; _i < _feeData.length; ++_i) {
      vm.expectEmit();
      emit IssuePayment(relay, relayCaller, _feeData[_i].feeRecipient, _feeData[_i].feeToken, _feeData[_i].fee);
    }

    automationVault.exec(relayCaller, _execData, _feeData);
  }
}
