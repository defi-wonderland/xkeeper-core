/// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {AutomationVault, IAutomationVault, EnumerableSet} from '@contracts/core/AutomationVault.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {_ETH, _ALL} from '@utils/Constants.sol';

contract AutomationVaultForTest is AutomationVault {
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor(address _owner, address _nativeToken) AutomationVault(_owner, _nativeToken) {}

  function setPendingOwnerForTest(address _pendingOwner) public {
    pendingOwner = _pendingOwner;
  }

  function addRelayCallerForTest(address _relay, address _caller) public {
    _approvedCallers[_relay].add(_caller);
  }

  function addJobSelectorForTest(address _relay, address _job, SelectorData memory _selectorData) public {
    _approvedJobs[_relay].add(_job);
    _approvedJobSelectorsList[_relay][_job].push(_selectorData.selector);
    _approvedJobSelectorsWithHooks[_relay][_job][_selectorData.selector] = _selectorData.hookData;
  }

  function addRelayForTest(
    address _relay,
    address[] memory _callers,
    address _job,
    bytes4[] memory _selectors,
    IAutomationVault.JobSelectorType[] memory _jobSelectorTypes,
    address[] memory _preHooks,
    address[] memory _postHooks
  ) public {
    for (uint256 _i; _i < _callers.length; ++_i) {
      _approvedCallers[_relay].add(_callers[_i]);
    }

    if (_job != address(0)) {
      _approvedJobs[_relay].add(_job);
    }

    for (uint256 _i; _i < _selectors.length; ++_i) {
      _approvedJobSelectorsList[_relay][_job].push(_selectors[_i]);
      _approvedJobSelectorsWithHooks[_relay][_job][_selectors[_i]] =
        IAutomationVault.HookData(_jobSelectorTypes[_i], _preHooks[_i], _postHooks[_i]);
    }

    _relays.add(_relay);
  }

  function getRelayDataForTest(address _relay)
    public
    view
    returns (address[] memory _callers, IAutomationVault.JobData[] memory _jobsData)
  {
    (_callers, _jobsData) = this.getRelayData(_relay);
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
  event WithdrawFunds(address indexed _token, uint256 _amount, address indexed _receiver);
  event ApproveRelay(address indexed _relay);
  event DeleteRelay(address indexed _relay);
  event ApproveRelayCaller(address indexed _relay, address indexed _caller);
  event ApproveJob(address indexed _job);
  event ApproveJobSelector(
    address indexed _job,
    bytes4 indexed _functionSelector,
    IAutomationVault.JobSelectorType _hookType,
    address _preHook,
    address _postHook
  );
  event JobExecuted(address indexed _relay, address indexed _relayCaller, address indexed _job, bytes _jobData);
  event IssuePayment(
    address indexed _relay, address indexed _relayCaller, address indexed _feeRecipient, address _feeToken, uint256 _fee
  );
  event NativeTokenReceived(address indexed _sender, uint256 _amount);

  /// AutomationVault contract
  AutomationVaultForTest public automationVault;

  /// Mock contracts
  address public token;

  /// EOAs
  address public owner;
  address public pendingOwner;
  address public receiver;

  // Mock arrays
  IAutomationVault.JobSelectorType[] public jobSelectorTypes;
  bytes4[] public selectors;
  address[] public preHooks;
  address[] public postHooks;

  function setUp() public virtual {
    owner = makeAddr('Owner');
    pendingOwner = makeAddr('PendingOwner');
    receiver = makeAddr('Receiver');
    token = makeAddr('Token');

    selectors = [
      bytes4(keccak256('selector1()')),
      bytes4(keccak256('selector2()')),
      bytes4(keccak256('selector3()')),
      bytes4(keccak256('selector4()')),
      bytes4(keccak256('selector5()'))
    ];

    preHooks =
      [makeAddr('PreHook1'), makeAddr('PreHook2'), makeAddr('PreHook3'), makeAddr('PreHook4'), makeAddr('PreHook5')];

    postHooks = [
      makeAddr('PostHook1'),
      makeAddr('PostHook2'),
      makeAddr('PostHook3'),
      makeAddr('PostHook4'),
      makeAddr('PostHook5')
    ];

    jobSelectorTypes = [
      IAutomationVault.JobSelectorType.DISABLED,
      IAutomationVault.JobSelectorType.ENABLED,
      IAutomationVault.JobSelectorType.ENABLED_WITH_PREHOOK,
      IAutomationVault.JobSelectorType.ENABLED_WITH_POSTHOOK,
      IAutomationVault.JobSelectorType.ENABLED_WITH_BOTHHOOKS
    ];

    automationVault = new AutomationVaultForTest(owner, _ETH);
  }

  /**
   * @notice Helper function to change the prank and expect revert if the caller is not the owner
   */
  function _revertOnlyOwner() internal {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector));
    changePrank(pendingOwner);
  }

  /**
   * @notice Helper function to change the prank and expect revert if the relay address is zero
   */
  function _revertRelayZero() internal {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_RelayZero.selector));
    vm.prank(owner);
  }

  /**
   * @notice Helper function to create the jobs data array
   * @param _job The job address
   * @param _selectorsData The selectors data array
   */
  function _createJobsData(
    address _job,
    IAutomationVault.SelectorData[] memory _selectorsData
  ) internal pure returns (IAutomationVault.JobData[] memory _jobsData) {
    _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0].job = _job;
    _jobsData[0].selectorsData = _selectorsData;
  }

  function _assumeRelayData(address _job, address _relay, address[] memory _callers) internal pure {
    vm.assume(_job != address(0));
    vm.assume(_relay != address(0));
    vm.assume(_callers.length > 0 && _callers.length < 30);
  }

  function _createSelectorsData(
    bytes4[] memory _selectors,
    IAutomationVault.JobSelectorType[] memory _jobSelectorTypes,
    address[] memory _preHooks,
    address[] memory _postHooks
  ) internal pure returns (IAutomationVault.SelectorData[] memory _selectorsData) {
    IAutomationVault.SelectorData[] memory _selectorsData = new IAutomationVault.SelectorData[](_selectors.length);

    for (uint256 _i; _i < _selectors.length; ++_i) {
      _selectorsData[_i] = IAutomationVault.SelectorData({
        selector: _selectors[_i],
        hookData: IAutomationVault.HookData(_jobSelectorTypes[_i], _preHooks[_i], _postHooks[_i])
      });
    }

    return _selectorsData;
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
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _cleanCallers;

  modifier happyPath(address _job, address _relay, address[] memory _callers) {
    _assumeRelayData(_job, _relay, _callers);

    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _callers.length; ++_i) {
      _cleanCallers.add(_callers[_i]);
    }

    automationVault.addRelayForTest(_relay, _callers, _job, selectors, jobSelectorTypes, preHooks, postHooks);

    vm.startPrank(owner);

    _;
  }

  /**
   * @notice Check that the relay data is correct
   */
  function testRelayData(
    address _job,
    address _relay,
    address[] memory _callers
  ) public happyPath(_job, _relay, _callers) {
    (address[] memory _relayCallers, IAutomationVault.JobData[] memory _jobsData) = automationVault.getRelayData(_relay);

    // Check the relay callers
    assertEq(_relayCallers.length, _cleanCallers.length());

    for (uint256 _i; _i < _relayCallers.length; ++_i) {
      assertEq(_relayCallers[_i], _cleanCallers.at(_i));
    }

    // Check the jobs
    assertEq(_jobsData[0].job, _job);

    // Check the function selectors
    assertEq(_jobsData[0].selectorsData.length, selectors.length);

    for (uint256 _i; _i < _jobsData[0].selectorsData.length; ++_i) {
      assertEq(_jobsData[0].selectorsData[_i].selector, selectors[_i]);
    }
  }
}

contract UnitAutomationVaultListRelays is AutomationVaultUnitTest {
  /**
   * @notice Check that the relays length is correct
   */
  function testRelaysLength(address _job, address _relay, address[] memory _callers) public {
    _assumeRelayData(_job, _relay, _callers);
    automationVault.addRelayForTest(_relay, _callers, _job, selectors, jobSelectorTypes, preHooks, postHooks);

    assertEq(automationVault.relays().length, 1);
    assertEq(automationVault.relays()[0], _relay);
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
    _revertOnlyOwner();
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
    _revertOnlyOwner();
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
contract UnitAutomationVaultAddRelayData is AutomationVaultUnitTest {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _cleanCallers;

  modifier happyPath(address _job, address _relay, address[] memory _callers) {
    /// @dev This is a workaround for the fact that the VM does not support dynamic arrays
    _assumeRelayData(_job, _relay, _callers);

    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _callers.length; ++_i) {
      _cleanCallers.add(_callers[_i]);
    }

    vm.startPrank(owner);
    _;
  }

  /**
   * @notice Checks that the test has to revert if the caller is not the owner
   */
  function testRevertIfCallerIsNotOwner(address _relay) public {
    _revertOnlyOwner();
    automationVault.addRelay(_relay, new address[](0), new IAutomationVault.JobData[](0));
  }

  /**
   * @notice Checks that the test has to revert if the relay address is zero
   */
  function testRevertIfRelayIsZero() public {
    _revertRelayZero();
    automationVault.addRelay(address(0), new address[](0), new IAutomationVault.JobData[](0));
  }

  /**
   * @notice Checks that revert if the relay is already approved
   */
  function testRevertIfRelayAlreadyApproved(address _relay) public {
    vm.assume(_relay != address(0));

    automationVault.addRelayForTest(
      _relay,
      new address[](0),
      address(0),
      new bytes4[](0),
      new IAutomationVault.JobSelectorType[](0),
      new address[](0),
      new address[](0)
    );

    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_RelayAlreadyApproved.selector));
    vm.prank(owner);
    automationVault.addRelay(_relay, new address[](0), new IAutomationVault.JobData[](0));
  }

  /**
   * @notice Emit ApproveRelay, ApproveRelayCaller, ApproveJob and ApproveJobSelector events when the relay is approved
   */
  function testEmitApproveRelayCallerJobAndSelector(
    address _job,
    address _relay,
    address[] memory _callers
  ) public happyPath(_job, _relay, _callers) {
    IAutomationVault.JobData[] memory _jobsData =
      _createJobsData(_job, _createSelectorsData(selectors, jobSelectorTypes, preHooks, postHooks));

    /// Emit ApproveRelay event
    vm.expectEmit();
    emit ApproveRelay(_relay);

    /// Emit ApproveRelayCaller event
    for (uint256 _i; _i < _cleanCallers.length(); _i++) {
      vm.expectEmit();
      emit ApproveRelayCaller(_relay, _cleanCallers.at(_i));
    }

    /// Emit ApproveJob event
    vm.expectEmit();
    emit ApproveJob(_job);

    /// Emit ApproveJobSelector event
    for (uint256 _i; _i < selectors.length; _i++) {
      vm.expectEmit();
      emit ApproveJobSelector(_job, selectors[_i], jobSelectorTypes[_i], preHooks[_i], postHooks[_i]);
    }

    automationVault.addRelay(_relay, _callers, _jobsData);
  }

  /**
   * @notice Test add relay with several jobs
   * @dev Isolated test to check that more than one job is added
   */
  function testAddRelayWithSeveralJobs(
    address _job,
    address _relay,
    address[] memory _callers,
    address _secondJob
  ) public {
    _assumeRelayData(_job, _relay, _callers);
    vm.assume(_secondJob != address(0));
    vm.assume(_job != _secondJob);

    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](2);
    _jobsData[0].job = _job;
    _jobsData[1].job = _secondJob;
    // we don't modify selectors here because it fails with panic out-of-bounds code

    vm.prank(owner);
    automationVault.addRelay(_relay, _callers, _jobsData);

    (, IAutomationVault.JobData[] memory _relayJobsData) = automationVault.getRelayDataForTest(_relay);

    assertEq(_relayJobsData.length, 2);
  }
}

/**
 * @dev Is not possible to create in the happy path type struct IAutomationVault.JobData memory[] memory to storage because is not yet supported.
 */
contract UnitAutomationVaultDeleteRelay is AutomationVaultUnitTest {
  modifier happyPath(address _job, address _relay, address[] memory _callers) {
    /// @dev This is a workaround for the fact that the VM does not support dynamic arrays
    _assumeRelayData(_job, _relay, _callers);

    automationVault.addRelayForTest(_relay, _callers, _job, selectors, jobSelectorTypes, preHooks, postHooks);

    vm.startPrank(owner);
    _;
  }

  /**
   * @notice Checks that the test has to revert if the caller is not the owner
   */
  function testRevertIfCallerIsNotOwner(address _relay) public {
    _revertOnlyOwner();
    automationVault.deleteRelay(_relay);
  }

  /**
   * @notice Checks that the test has to revert if the relay address is zero
   */
  function testRevertIfRelayIsZero() public {
    _revertRelayZero();
    automationVault.deleteRelay(address(0));
  }

  /**
   * @notice Checks that mappings associated with the relay are deleted
   */
  function testMappingsAreDeleted(
    address _job,
    address _relay,
    address[] memory _callers
  ) public happyPath(_job, _relay, _callers) {
    automationVault.deleteRelay(_relay);

    (address[] memory _relayCallers, IAutomationVault.JobData[] memory _jobData) =
      automationVault.getRelayDataForTest(_relay);

    assertEq(automationVault.relays().length, 0);
    assertEq(_relayCallers.length, 0);
    assertEq(_jobData.length, 0);
  }

  /**
   * @notice Emit DeleteRelay event when the relay is deleted
   */
  function testEmitDeleteRelay(
    address _job,
    address _relay,
    address[] memory _callers
  ) public happyPath(_job, _relay, _callers) {
    vm.expectEmit();
    emit DeleteRelay(_relay);

    automationVault.deleteRelay(_relay);
  }
}

/**
 * @dev Is not possible to create in the happy path type struct IAutomationVault.JobData memory[] memory to storage because is not yet supported.
 */
contract UnitAutomationVaultModifyRelay is AutomationVaultUnitTest {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _cleanCallers;

  modifier happyPath(address _job, address _relay, address[] memory _callers) {
    /// @dev This is a workaround for the fact that the VM does not support dynamic arrays
    _assumeRelayData(_job, _relay, _callers);

    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _callers.length; ++_i) {
      _cleanCallers.add(_callers[_i]);
    }

    automationVault.addRelayForTest(
      _relay,
      new address[](0),
      address(0),
      new bytes4[](0),
      new IAutomationVault.JobSelectorType[](0),
      new address[](0),
      new address[](0)
    );

    vm.startPrank(owner);
    _;
  }
  /**
   * @notice Checks that the test has to revert if the caller is not the owner
   */

  function testRevertIfCallerIsNotOwner(address _relay) public {
    _revertOnlyOwner();
    automationVault.modifyRelay(_relay, new address[](0), new IAutomationVault.JobData[](0));
  }

  /**
   * @notice Checks that the test has to revert if the relay address is zero
   */
  function testRevertIfRelayIsZero() public {
    _revertRelayZero();
    automationVault.modifyRelay(address(0), new address[](0), new IAutomationVault.JobData[](0));
  }

  /**
   * @notice Checks that callers are modified correctly
   */
  function testRelayCallersAreModified(
    address _job,
    address _relay,
    address[] memory _callers
  ) public happyPath(_job, _relay, _callers) {
    // Get the list of callers
    (address[] memory _relayCallers,) = automationVault.getRelayDataForTest(_relay);

    // Length should be zero
    assertEq(_relayCallers.length, 0);

    // Create the array of jobs data with the jobs length
    IAutomationVault.JobData[] memory _jobsData =
      _createJobsData(_job, _createSelectorsData(selectors, jobSelectorTypes, preHooks, postHooks));

    // Modify the callers
    automationVault.modifyRelay(_relay, _callers, _jobsData);

    // Get the list of callers
    (_relayCallers,) = automationVault.getRelayDataForTest(_relay);

    for (uint256 _i; _i < _relayCallers.length; ++_i) {
      assertEq(_relayCallers[_i], _cleanCallers.at(_i));
    }
  }

  /**
   * @notice Checks that jobs and selectors are modified correctly
   */
  function testRelayJobsAndSelectorsAreModified(
    address _job,
    address _relay,
    address[] memory _callers
  ) public happyPath(_job, _relay, _callers) {
    // Get the list of callers
    (, IAutomationVault.JobData[] memory _jobsData) = automationVault.getRelayDataForTest(_relay);

    // Length should be zero
    assertEq(_jobsData.length, 0);

    _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0].job = _job;
    _jobsData[0].selectorsData = _createSelectorsData(selectors, jobSelectorTypes, preHooks, postHooks);

    // Modify the callers
    automationVault.modifyRelay(_relay, _callers, _jobsData);

    // Get the list of callers
    (, _jobsData) = automationVault.getRelayDataForTest(_relay);

    for (uint256 _i; _i < _jobsData.length; ++_i) {
      assertEq(_jobsData[_i].job, _job);
      assertEq(_jobsData[_i].selectorsData.length, selectors.length);

      for (uint256 _j; _j < _jobsData[_i].selectorsData.length; ++_j) {
        assertEq(_jobsData[_i].selectorsData[_j].selector, selectors[_j]);
      }
    }
  }

  /**
   * @notice Emit ApproveRelayCaller, ApproveJob and ApproveJobSelector events when the relay is modified
   */
  function testEmitApproveCallersJobAndSelectors(
    address _job,
    address _relay,
    address[] memory _callers
  ) public happyPath(_job, _relay, _callers) {
    IAutomationVault.JobData[] memory _jobsData =
      _createJobsData(_job, _createSelectorsData(selectors, jobSelectorTypes, preHooks, postHooks));

    // Emit ApproveRelayCaller event
    for (uint256 _i; _i < _cleanCallers.length(); ++_i) {
      vm.expectEmit();
      emit ApproveRelayCaller(_relay, _cleanCallers.at(_i));
    }

    // Emit ApproveJob event
    vm.expectEmit();
    emit ApproveJob(_job);

    // Emit ApproveJobSelector event
    for (uint256 _i; _i < selectors.length; ++_i) {
      vm.expectEmit();
      emit ApproveJobSelector(_job, selectors[_i], jobSelectorTypes[_i], preHooks[_i], postHooks[_i]);
    }

    automationVault.modifyRelay(_relay, _callers, _jobsData);
  }

  /**
   * @notice Test modify relay with several jobs
   * @dev Isolated test to check that more than one job is added
   */
  function testModifyRelayWithSeveralJobs(
    address _relay,
    address[] memory _callers,
    address _job,
    address _secondJob
  ) public {
    _assumeRelayData(_job, _relay, _callers);
    vm.assume(_job != address(0));
    vm.assume(_secondJob != address(0));
    vm.assume(_job != _secondJob);

    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](2);
    _jobsData[0].job = _job;
    _jobsData[1].job = _secondJob;

    vm.prank(owner);
    automationVault.modifyRelay(_relay, _callers, _jobsData);

    (, IAutomationVault.JobData[] memory _relayJobsData) = automationVault.getRelayDataForTest(_relay);

    assertEq(_relayJobsData.length, 2);
    assertEq(_relayJobsData[0].job, _job);
    assertEq(_relayJobsData[1].job, _secondJob);
  }
}

/**
 * @dev Is not possible to create in the happy path type struct IAutomationVault.JobData memory[] memory to storage because is not yet supported.
 */
contract UnitAutomationVaultModifyRelayCallers is AutomationVaultUnitTest {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _cleanCallers;

  modifier happyPath(address _relay, address[] memory _callers) {
    /// @dev This is a workaround for the fact that the VM does not support dynamic arrays
    _assumeRelayData(makeAddr('job'), _relay, _callers);

    automationVault.addRelayForTest(
      _relay,
      new address[](0),
      address(0),
      new bytes4[](0),
      new IAutomationVault.JobSelectorType[](0),
      new address[](0),
      new address[](0)
    );

    for (uint256 _i; _i < _callers.length; ++_i) {
      _cleanCallers.add(_callers[_i]);
    }

    vm.startPrank(owner);
    _;
  }

  /**
   * @notice Checks that the test has to revert if the caller is not the owner
   */
  function testRevertIfCallerIsNotOwner(address _relay, address[] memory _callers) public {
    _revertOnlyOwner();
    automationVault.modifyRelayCallers(_relay, _callers);
  }

  /**
   * @notice Checks that the test has to revert if the relay address is zero
   */
  function testRevertIfRelayIsZero() public {
    _revertRelayZero();
    automationVault.modifyRelayCallers(address(0), new address[](0));
  }

  /**
   * @notice Checks that callers are modified correctly
   */
  function testRelayCallersAreModified(address _relay, address[] memory _callers) public happyPath(_relay, _callers) {
    // Get the list of callers
    (address[] memory _relayCallers,) = automationVault.getRelayDataForTest(_relay);

    // Length should be zero
    assertEq(_relayCallers.length, 0);

    // Modify the callers
    automationVault.modifyRelayCallers(_relay, _callers);

    // Get the list of callers
    (_relayCallers,) = automationVault.getRelayDataForTest(_relay);

    for (uint256 _i; _i < _relayCallers.length; ++_i) {
      assertEq(_relayCallers[_i], _cleanCallers.at(_i));
    }
  }

  /**
   * @notice Emit ApproveRelayCaller event when the relay caller is approved
   */
  function testEmitApproveRelayCaller(address _relay, address[] memory _callers) public happyPath(_relay, _callers) {
    for (uint256 _i; _i < _cleanCallers.length(); ++_i) {
      vm.expectEmit();
      emit ApproveRelayCaller(_relay, _cleanCallers.at(_i));
    }

    automationVault.modifyRelayCallers(_relay, _callers);
  }
}

/**
 * @dev Is not possible to create in the happy path type struct IAutomationVault.JobData memory[] memory to storage because is not yet supported.
 */
contract UnitAutomationVaultModifyRelayJobs is AutomationVaultUnitTest {
  modifier happyPath(address _job, address _relay) {
    /// @dev This is a workaround for the fact that the VM does not support dynamic arrays
    _assumeRelayData(_job, _relay, new address[](1));

    automationVault.addRelayForTest(
      _relay,
      new address[](0),
      address(0),
      new bytes4[](1),
      new IAutomationVault.JobSelectorType[](1),
      new address[](1),
      new address[](1)
    );

    vm.startPrank(owner);
    _;
  }

  /**
   * @notice Checks that the test has to revert if the caller is not the owner
   */
  function testRevertIfCallerIsNotOwner(address _relay) public {
    _revertOnlyOwner();
    automationVault.modifyRelayJobs(_relay, new IAutomationVault.JobData[](0));
  }

  /**
   * @notice Checks that the test has to revert if the relay address is zero
   */
  function testRevertIfRelayIsZero() public {
    _revertRelayZero();
    automationVault.modifyRelayJobs(address(0), new IAutomationVault.JobData[](0));
  }

  /**
   * @notice Checks that jobs and selectors are modified correctly
   */
  function testRelayJobsAndSelectorsAreModified(address _job, address _relay) public happyPath(_job, _relay) {
    // Get the list of jobs data for the relay
    (, IAutomationVault.JobData[] memory _jobsData) = automationVault.getRelayDataForTest(_relay);

    // Length should be zero
    assertEq(_jobsData.length, 0);

    _jobsData = _createJobsData(_job, _createSelectorsData(selectors, jobSelectorTypes, preHooks, postHooks));

    // Modify the relay jobs
    automationVault.modifyRelayJobs(_relay, _jobsData);

    // Get the list of jobs data for the relay
    (, _jobsData) = automationVault.getRelayDataForTest(_relay);

    for (uint256 _i; _i < _jobsData.length; ++_i) {
      assertEq(_jobsData[_i].job, _job);
      assertEq(_jobsData[_i].selectorsData.length, selectors.length);

      for (uint256 _j; _j < _jobsData[_i].selectorsData.length; ++_j) {
        assertEq(_jobsData[_i].selectorsData[_j].selector, selectors[_j]);
      }
    }
  }

  /**
   * @notice Emit ApproveJob and ApproveJobSelector events when the relay is modified
   */
  function testEmitApproveJobAndSelector(address _job, address _relay) public happyPath(_relay, _job) {
    IAutomationVault.JobData[] memory _jobsData =
      _createJobsData(_job, _createSelectorsData(selectors, jobSelectorTypes, preHooks, postHooks));

    vm.expectEmit();
    emit ApproveJob(_job);

    for (uint256 _i; _i < selectors.length; ++_i) {
      vm.expectEmit();
      emit ApproveJobSelector(_job, selectors[_i], jobSelectorTypes[_i], preHooks[_i], postHooks[_i]);
    }

    automationVault.modifyRelayJobs(_relay, _jobsData);
  }

  /**
   * @notice Test modify relay jobs with several jobs
   * @dev Isolated test to check that more than one job is added
   */
  function testModifyRelayJobsWithSeveralJobs(
    address _job,
    address _relay,
    address[] memory _callers,
    address _secondJob
  ) public {
    _assumeRelayData(_job, _relay, _callers);
    vm.assume(_secondJob != address(0));
    vm.assume(_job != _secondJob);

    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](2);
    _jobsData[0].job = _job;
    _jobsData[1].job = _secondJob;

    vm.prank(owner);
    automationVault.modifyRelayJobs(_relay, _jobsData);

    (, IAutomationVault.JobData[] memory _relayJobsData) = automationVault.getRelayDataForTest(_relay);

    assertEq(_relayJobsData.length, 2);
    assertEq(_relayJobsData[0].job, _job);
    assertEq(_relayJobsData[1].job, _secondJob);
  }
}

contract UnitAutomationVaultExec is AutomationVaultUnitTest {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  IAutomationVault.FeeData[] private _feeData;
  IAutomationVault.ExecData[] private _execData;
  EnumerableSet.Bytes32Set private _cleanRandomBytes32;
  IAutomationVault.SelectorData[] private _selectorsData;

  modifier happyPath(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32,
    IAutomationVault.JobSelectorType _jobSelectorType
  ) {
    vm.assume(_randomBytes32.length > 3 && _randomBytes32.length < 30);

    // Add the relay caller
    automationVault.addRelayCallerForTest(_relay, _caller);

    // Clean randomBytes32
    for (uint256 _i; _i < _randomBytes32.length; ++_i) {
      _cleanRandomBytes32.add(_randomBytes32[_i]);
    }

    // Copy clean bytes32
    _randomBytes32 = new bytes32[](_cleanRandomBytes32.length());
    for (uint256 _i; _i < _cleanRandomBytes32.length(); ++_i) {
      _randomBytes32[_i] = _cleanRandomBytes32.at(_i);
    }

    // Create clean execData
    _execData = _createRandomExecData(_randomBytes32);

    // Create clean feeData
    _feeData = _createRandomFeeData(_randomBytes32);

    // create random selectors data
    _selectorsData = _createRandomSelectorsData(_execData, _jobSelectorType);

    // Add the job and the selector
    for (uint256 _i; _i < _execData.length; ++_i) {
      automationVault.addJobSelectorForTest(_relay, _execData[_i].job, _selectorsData[_i]);
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

    vm.startPrank(_relay);
    _;
  }

  /**
   * @notice Create random selectors data
   */
  function _createRandomSelectorsData(
    IAutomationVault.ExecData[] memory _randomExecData,
    IAutomationVault.JobSelectorType _jobSelectorType
  ) internal pure returns (IAutomationVault.SelectorData[] memory _selectorsData) {
    // create selectors for each job
    bytes4[] memory _selectors = new bytes4[](_randomExecData.length);
    for (uint256 _i; _i < _randomExecData.length; ++_i) {
      _selectors[_i] = bytes4(_randomExecData[_i].jobData);
    }

    // create JobSelectorType for each job
    IAutomationVault.JobSelectorType[] memory _jobSelectorTypes =
      new IAutomationVault.JobSelectorType[](_randomExecData.length);
    for (uint256 _i; _i < _randomExecData.length; ++_i) {
      _jobSelectorTypes[_i] = _jobSelectorType;
    }

    // create preHooks for each job
    address[] memory _preHooks = new address[](_randomExecData.length);
    for (uint256 _i; _i < _randomExecData.length; ++_i) {
      _preHooks[_i] = address(uint160(uint256(keccak256(abi.encode(_selectors[_i], 'preHooks')))));
    }

    // create postHooks for each job
    address[] memory _postHooks = new address[](_randomExecData.length);
    for (uint256 _i; _i < _randomExecData.length; ++_i) {
      _postHooks[_i] = address(uint160(uint256(keccak256(abi.encode(_selectors[_i], 'postHooks')))));
    }

    return _createSelectorsData(_selectors, _jobSelectorTypes, _preHooks, _postHooks);
  }

  /**
   * @notice Create random exec data
   */
  function _createRandomExecData(bytes32[] memory _randomBytes32)
    internal
    pure
    returns (IAutomationVault.ExecData[] memory _randomExecData)
  {
    IAutomationVault.ExecData[] memory _randomExecData = new IAutomationVault.ExecData[](_randomBytes32.length);
    for (uint256 _i; _i < _randomBytes32.length; ++_i) {
      _randomExecData[_i] = IAutomationVault.ExecData({
        job: address(uint160(uint256(keccak256(abi.encode(_randomBytes32[_i], 'job'))))),
        jobData: abi.encodePacked(keccak256(abi.encode(_randomBytes32[_i], 'jobData')))
      });
    }
    return _randomExecData;
  }

  /**
   * @notice Create random fee data
   */
  function _createRandomFeeData(bytes32[] memory _randomBytes32)
    internal
    pure
    returns (IAutomationVault.FeeData[] memory _randomFeeData)
  {
    IAutomationVault.FeeData[] memory _randomFeeData = new IAutomationVault.FeeData[](_randomBytes32.length);
    for (uint256 _i; _i < _randomBytes32.length; ++_i) {
      _randomFeeData[_i] = IAutomationVault.FeeData({
        feeRecipient: address(uint160(uint256(keccak256(abi.encode(_randomBytes32[_i], 'feeRecipient'))))),
        feeToken: address(uint160(uint256(keccak256(abi.encode(_randomBytes32[_i], 'feeToken'))))),
        fee: uint256(keccak256(abi.encode(_randomBytes32[_i], 'fee')))
      });
    }
    return _randomFeeData;
  }

  /**
   * @notice Checks that the test has to revert if the caller is not the relay caller
   */
  function testRevertIfNotApprovedRelayCaller(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED) {
    vm.expectRevert(IAutomationVault.AutomationVault_NotApprovedRelayCaller.selector);

    changePrank(owner);
    automationVault.exec(_caller, _execData, _feeData);
  }

  /**
   * @notice Checks that the test has to revert if the job is not approved
   */
  function testRevertIfNotApprovedJobSelector(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED) {
    _execData = new IAutomationVault.ExecData[](1);

    vm.expectRevert(IAutomationVault.AutomationVault_NotApprovedJobSelector.selector);
    automationVault.exec(_caller, _execData, _feeData);
  }

  /**
   * @notice Checks that the test has to revert if the job call failed
   */
  function testRevertIfJobCallFailed(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED) {
    vm.etch(_execData[1].job, type(NoFallbackForTest).runtimeCode);
    vm.mockCallRevert(_execData[1].job, abi.encodeWithSelector(bytes4(_execData[1].jobData)), abi.encode());

    vm.expectRevert(IAutomationVault.AutomationVault_ExecFailed.selector);

    automationVault.exec(_caller, _execData, _feeData);
  }

  /**
   * @notice Checks that call is executed correctly without fees
   */
  function testCallOnlyJobFunction(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED) {
    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.expectCall(_execData[_i].job, _execData[_i].jobData, 1);
    }

    automationVault.exec(_caller, _execData, new IAutomationVault.FeeData[](0));
  }

  /**
   * @notice Checks that call is executed correctly without hooks
   */
  function testCallJobFunctionWithoutHooks(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED) {
    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.expectCall(_execData[_i].job, _execData[_i].jobData, 1);
      vm.expectCall(_selectorsData[_i].hookData.preHook, _execData[_i].jobData, 0);
      vm.expectCall(_selectorsData[_i].hookData.postHook, '', 0);
    }

    automationVault.exec(_caller, _execData, _feeData);
  }

  /**
   * @notice Checks that call is executed correctly with pre-hook
   */
  function testCallJobFunctionWithPreHook(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED_WITH_PREHOOK) {
    for (uint256 _i; _i < _execData.length; ++_i) {
      (, bytes memory _preHookReturnData) = _selectorsData[_i].hookData.preHook.call(_execData[_i].jobData);

      vm.expectCall(_selectorsData[_i].hookData.preHook, _execData[_i].jobData, 1);
      vm.expectCall(_execData[_i].job, _preHookReturnData, 1);
      vm.expectCall(_selectorsData[_i].hookData.postHook, '', 0);
    }

    automationVault.exec(_caller, _execData, _feeData);
  }

  /**
   * @notice Checks that call is executed correctly with post-hook
   */
  function testCallJobFunctionWithPostHook(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED_WITH_POSTHOOK) {
    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.expectCall(_selectorsData[_i].hookData.preHook, _execData[_i].jobData, 0);
      vm.expectCall(_execData[_i].job, _execData[_i].jobData, 1);
      vm.expectCall(_selectorsData[_i].hookData.postHook, '', 1);
    }

    automationVault.exec(_caller, _execData, _feeData);
  }

  /**
   * @notice Checks that call is executed correctly with post-hook
   */
  function testCallJobFunctionWithBothHooks(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED_WITH_BOTHHOOKS) {
    for (uint256 _i; _i < _execData.length; ++_i) {
      (, bytes memory _preHookReturnData) = _selectorsData[_i].hookData.preHook.call(_execData[_i].jobData);

      vm.expectCall(_selectorsData[_i].hookData.preHook, _execData[_i].jobData, 1);
      vm.expectCall(_execData[_i].job, _preHookReturnData, 1);
      vm.expectCall(_selectorsData[_i].hookData.postHook, '', 1);
    }

    automationVault.exec(_caller, _execData, _feeData);
  }

  /**
   * @notice Checks that call is executed correctly with fees and open sender
   */
  function testCallJobFunctionWithOpenSender(
    address _relay,
    bytes32[] memory _randomBytes32,
    address _sender
  ) public happyPath(_relay, _ALL, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED) {
    vm.assume(_selectorsData[0].hookData.selectorType == IAutomationVault.JobSelectorType.ENABLED);

    IAutomationVault.ExecData[] memory _execDataOpen = new IAutomationVault.ExecData[](1);
    _execDataOpen[0].job = _execData[0].job;
    _execDataOpen[0].jobData = _execData[0].jobData;

    vm.expectCall(_execDataOpen[0].job, _execDataOpen[0].jobData, 1);

    automationVault.exec(_sender, _execDataOpen, _feeData);
  }

  /**
   * @notice Emit JobExecuted event when the job is executed
   */
  function testEmitJobExecuted(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED) {
    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.expectEmit();
      emit JobExecuted(_relay, _caller, _execData[_i].job, _execData[_i].jobData);
    }

    automationVault.exec(_caller, _execData, _feeData);
  }

  /**
   * @notice Checks that the test has to revert if the native token transfer failed
   */
  function testRevertIfNativeTokenTransferFailed(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED) {
    _feeData[1].feeToken = _ETH;
    vm.etch(_feeData[1].feeRecipient, type(NoFallbackForTest).runtimeCode);

    vm.expectRevert(IAutomationVault.AutomationVault_NativeTokenTransferFailed.selector);

    automationVault.exec(_caller, _execData, _feeData);
  }

  /**
   * @notice Checks that native token transfer is executed correctly
   */
  function testCallNativeTokenTransfer(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32,
    uint128 _fee
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED) {
    for (uint256 _i; _i < _feeData.length; ++_i) {
      _feeData[_i].feeToken = _ETH;
      _feeData[_i].fee = _fee;
    }

    automationVault.exec(_caller, _execData, _feeData);

    for (uint256 _i; _i < _feeData.length; ++_i) {
      assertGe(_feeData[_i].feeRecipient.balance, _feeData[_i].fee);
    }
  }

  /**
   * @notice Checks that token transfer is executed correctly
   */
  function testCallTokenTransfer(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED) {
    for (uint256 _i; _i < _feeData.length; ++_i) {
      vm.assume(_feeData[_i].feeToken != _ETH);
    }

    for (uint256 _i; _i < _feeData.length; ++_i) {
      vm.expectCall(
        _feeData[_i].feeToken, abi.encodeCall(IERC20.transfer, (_feeData[_i].feeRecipient, _feeData[_i].fee)), 1
      );
    }

    automationVault.exec(_caller, _execData, _feeData);
  }

  /**
   * @notice Emit IssuePayment event when the payment is issued
   */
  function testEmitIssuePayment(
    address _relay,
    address _caller,
    bytes32[] memory _randomBytes32
  ) public happyPath(_relay, _caller, _randomBytes32, IAutomationVault.JobSelectorType.ENABLED) {
    for (uint256 _i; _i < _feeData.length; ++_i) {
      vm.expectEmit();
      emit IssuePayment(_relay, _caller, _feeData[_i].feeRecipient, _feeData[_i].feeToken, _feeData[_i].fee);
    }

    automationVault.exec(_caller, _execData, _feeData);
  }
}
