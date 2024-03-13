/// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {AutomationVault, IAutomationVault, EnumerableSet} from '@contracts/core/AutomationVault.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {_NATIVE_TOKEN, _ALL} from '@utils/Constants.sol';

contract AutomationVaultForTest is AutomationVault {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(address _owner, address _nativeToken) AutomationVault(_owner, _nativeToken) {}

  function setPendingOwnerForTest(address _pendingOwner) public {
    pendingOwner = _pendingOwner;
  }

  function addRelayCallerForTest(address _relay, address _caller) public {
    _approvedCallers[_relay].add(_caller);
  }

  function addJobSelectorForTest(address _relay, address _job, bytes4 _selector) public {
    _approvedJobs[_relay].add(_job);
    _approvedJobSelectors[_relay][_job].add(bytes32(_selector));
  }

  function addRelayForTest(address _relay, address[] memory _callers, address _job, bytes4[] memory _selectors) public {
    for (uint256 _i; _i < _callers.length; ++_i) {
      _approvedCallers[_relay].add(_callers[_i]);
    }

    if (_job != address(0)) {
      _approvedJobs[_relay].add(_job);
    }

    for (uint256 _i; _i < _selectors.length; ++_i) {
      _approvedJobSelectors[_relay][_job].add(_selectors[_i]);
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
  event ApproveJobSelector(address indexed _job, bytes4 indexed _functionSelector);
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

  function setUp() public virtual {
    owner = makeAddr('Owner');
    pendingOwner = makeAddr('PendingOwner');
    receiver = makeAddr('Receiver');
    token = makeAddr('Token');

    automationVault = new AutomationVaultForTest(owner, _NATIVE_TOKEN);
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
   * @param _selectors The function selectors
   */
  function _createJobsData(
    address _job,
    bytes4[] memory _selectors
  ) internal pure returns (IAutomationVault.JobData[] memory _jobsData) {
    _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _selectors;
  }

  /**
   * @notice Helper function to create the assumes
   * @param _relay The relay address
   * @param _callers The callers array
   * @param _job The job address
   * @param _selectors The function selectors
   */
  function _assumeRelayData(
    address _relay,
    address[] memory _callers,
    address _job,
    bytes4[] memory _selectors
  ) internal pure {
    vm.assume(_relay != address(0));
    vm.assume(_job != address(0));
    vm.assume(_callers.length > 0 && _callers.length < 30);
    vm.assume(_selectors.length > 0 && _selectors.length < 30);
  }
}

contract UnitAutomationVaultConstructor is AutomationVaultUnitTest {
  /**
   * @notice Check that the constructor sets the params correctly
   */
  function testParamsAreSet() public {
    assertEq(automationVault.owner(), owner);
    assertEq(automationVault.NATIVE_TOKEN(), _NATIVE_TOKEN);
  }
}

contract UnitGetRelayData is AutomationVaultUnitTest {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  EnumerableSet.AddressSet internal _cleanCallers;
  EnumerableSet.Bytes32Set internal _cleanSelectors;

  modifier happyPath(address _relay, address[] memory _callers, address _job, bytes4[] memory _selectors) {
    _assumeRelayData(_relay, _callers, _job, _selectors);

    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _callers.length; ++_i) {
      _cleanCallers.add(_callers[_i]);
    }

    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _selectors.length; ++_i) {
      _cleanSelectors.add(_selectors[_i]);
    }

    automationVault.addRelayForTest(_relay, _callers, _job, _selectors);

    vm.startPrank(owner);

    _;
  }
  /**
   * @notice Check that the relay data is correct
   */

  function testRelayData(
    address _relay,
    address[] memory _callers,
    address _job,
    bytes4[] memory _selectors
  ) public happyPath(_relay, _callers, _job, _selectors) {
    (address[] memory _relayCallers, IAutomationVault.JobData[] memory _jobsData) = automationVault.getRelayData(_relay);

    // Check the relay callers
    assertEq(_relayCallers.length, _cleanCallers.length());

    for (uint256 _i; _i < _relayCallers.length; ++_i) {
      assertEq(_relayCallers[_i], _cleanCallers.at(_i));
    }

    // Check the jobs
    assertEq(_jobsData[0].job, _job);

    // Check the function selectors
    assertEq(_jobsData[0].functionSelectors.length, _cleanSelectors.length());

    for (uint256 _i; _i < _jobsData[0].functionSelectors.length; ++_i) {
      assertEq(_jobsData[0].functionSelectors[_i], _cleanSelectors.at(_i));
    }
  }
}

contract UnitAutomationVaultListRelays is AutomationVaultUnitTest {
  /**
   * @notice Check that the relays length is correct
   */
  function testRelaysLength(address _relay, address[] memory _callers, address _job, bytes4[] memory _selectors) public {
    automationVault.addRelayForTest(_relay, _callers, _job, _selectors);

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
    automationVault.withdrawFunds(_NATIVE_TOKEN, _amount, owner);
  }

  /**
   * @notice Checks that the test has to revert if the native token transfer failed
   */
  function testRevertIfNativeTokenTransferFailed() public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_NativeTokenTransferFailed.selector));

    vm.prank(owner);
    automationVault.withdrawFunds(_NATIVE_TOKEN, type(uint160).max, address(automationVault));
  }

  /**
   * @notice Checks that the balances are updated correctly
   */
  function testWithdrawNativeTokenAmountUpdateBalances(uint128 _amount) public happyPath(_amount) {
    automationVault.withdrawFunds(_NATIVE_TOKEN, _amount, receiver);

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
    emit WithdrawFunds(_NATIVE_TOKEN, _amount, receiver);

    automationVault.withdrawFunds(_NATIVE_TOKEN, _amount, receiver);
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
  using EnumerableSet for EnumerableSet.Bytes32Set;

  EnumerableSet.AddressSet internal _cleanCallers;
  EnumerableSet.Bytes32Set internal _cleanSelectors;

  modifier happyPath(address _relay, address[] memory _callers, address _job, bytes4[] memory _selectors) {
    /// @dev This is a workaround for the fact that the VM does not support dynamic arrays
    _assumeRelayData(_relay, _callers, _job, _selectors);

    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _callers.length; ++_i) {
      _cleanCallers.add(_callers[_i]);
    }

    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _selectors.length; ++_i) {
      _cleanSelectors.add(_selectors[_i]);
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

    automationVault.addRelayForTest(_relay, new address[](0), address(0), new bytes4[](0));

    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_RelayAlreadyApproved.selector));
    vm.prank(owner);
    automationVault.addRelay(_relay, new address[](0), new IAutomationVault.JobData[](0));
  }

  /**
   * @notice Emit ApproveRelay, ApproveRelayCaller, ApproveJob and ApproveJobSelector events when the relay is approved
   */
  function testEmitApproveRelayCallerJobAndSelector(
    address _relay,
    address[] memory _callers,
    address _job,
    bytes4[] memory _selectors
  ) public happyPath(_relay, _callers, _job, _selectors) {
    IAutomationVault.JobData[] memory _jobsData = _createJobsData(_job, _selectors);

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
    for (uint256 _i; _i < _cleanSelectors.length(); _i++) {
      vm.expectEmit();
      emit ApproveJobSelector(_job, bytes4(_cleanSelectors.at(_i)));
    }

    automationVault.addRelay(_relay, _callers, _jobsData);
  }

  /**
   * @notice Test add relay with several jobs
   * @dev Isolated test to check that more than one job is added
   */
  function testAddRelayWithSeveralJobs(
    address _relay,
    address[] memory _callers,
    address _job,
    bytes4[] memory _selectors,
    address _secondJob,
    bytes4[] memory _secondSelectors
  ) public {
    _assumeRelayData(_relay, _callers, _job, _selectors);
    vm.assume(_secondJob != address(0));
    vm.assume(_job != _secondJob);

    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](2);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _selectors;
    _jobsData[1].job = _secondJob;
    _jobsData[1].functionSelectors = _secondSelectors;

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
  modifier happyPath(address _relay, address[] memory _callers, address _job, bytes4[] memory _selectors) {
    /// @dev This is a workaround for the fact that the VM does not support dynamic arrays
    _assumeRelayData(_relay, _callers, _job, _selectors);

    automationVault.addRelayForTest(_relay, _callers, _job, _selectors);

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
    address _relay,
    address[] memory _callers,
    address _job,
    bytes4[] memory _selectors
  ) public happyPath(_relay, _callers, _job, _selectors) {
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
    address _relay,
    address[] memory _callers,
    address _job,
    bytes4[] memory _selectors
  ) public happyPath(_relay, _callers, _job, _selectors) {
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
  using EnumerableSet for EnumerableSet.Bytes32Set;

  EnumerableSet.AddressSet internal _cleanCallers;
  EnumerableSet.Bytes32Set internal _cleanSelectors;

  modifier happyPath(address _relay, address[] memory _callers, address _job, bytes4[] memory _selectors) {
    /// @dev This is a workaround for the fact that the VM does not support dynamic arrays
    _assumeRelayData(_relay, _callers, _job, _selectors);

    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _callers.length; ++_i) {
      _cleanCallers.add(_callers[_i]);
    }

    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _selectors.length; ++_i) {
      _cleanSelectors.add(_selectors[_i]);
    }

    automationVault.addRelayForTest(_relay, new address[](0), address(0), new bytes4[](0));

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
    address _relay,
    address[] memory _callers,
    address _job,
    bytes4[] memory _selectors
  ) public happyPath(_relay, _callers, _job, _selectors) {
    // Get the list of callers
    (address[] memory _relayCallers,) = automationVault.getRelayDataForTest(_relay);

    // Length should be zero
    assertEq(_relayCallers.length, 0);

    // Create the array of jobs data with the jobs length
    IAutomationVault.JobData[] memory _jobsData = _createJobsData(_job, _selectors);

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
    address _relay,
    address[] memory _callers,
    address _job,
    bytes4[] memory _selectors
  ) public happyPath(_relay, _callers, _job, _selectors) {
    // Get the list of callers
    (, IAutomationVault.JobData[] memory _jobsData) = automationVault.getRelayDataForTest(_relay);

    // Length should be zero
    assertEq(_jobsData.length, 0);

    _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _selectors;

    // Modify the callers
    automationVault.modifyRelay(_relay, _callers, _jobsData);

    // Get the list of callers
    (, _jobsData) = automationVault.getRelayDataForTest(_relay);

    for (uint256 _i; _i < _jobsData.length; ++_i) {
      assertEq(_jobsData[_i].job, _job);
      assertEq(_jobsData[_i].functionSelectors.length, _cleanSelectors.length());

      for (uint256 _j; _j < _jobsData[_i].functionSelectors.length; ++_j) {
        assertEq(_jobsData[_i].functionSelectors[_j], _cleanSelectors.at(_j));
      }
    }
  }

  /**
   * @notice Emit ApproveRelayCaller, ApproveJob and ApproveJobSelector events when the relay is modified
   */
  function testEmitApproveCallersJobAndSelectors(
    address _relay,
    address[] memory _callers,
    address _job,
    bytes4[] memory _selectors
  ) public happyPath(_relay, _callers, _job, _selectors) {
    IAutomationVault.JobData[] memory _jobsData = _createJobsData(_job, _selectors);

    // Emit ApproveRelayCaller event
    for (uint256 _i; _i < _cleanCallers.length(); ++_i) {
      vm.expectEmit();
      emit ApproveRelayCaller(_relay, _cleanCallers.at(_i));
    }

    // Emit ApproveJob event
    vm.expectEmit();
    emit ApproveJob(_job);

    // Emit ApproveJobSelector event
    for (uint256 _i; _i < _cleanSelectors.length(); ++_i) {
      vm.expectEmit();
      emit ApproveJobSelector(_job, bytes4(_cleanSelectors.at(_i)));
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
    bytes4[] memory _selectors,
    address _secondJob,
    bytes4[] memory _secondSelectors
  ) public {
    _assumeRelayData(_relay, _callers, _job, _selectors);
    vm.assume(_job != address(0));
    vm.assume(_secondJob != address(0));
    vm.assume(_job != _secondJob);

    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](2);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _selectors;
    _jobsData[1].job = _secondJob;
    _jobsData[1].functionSelectors = _secondSelectors;

    vm.prank(owner);
    automationVault.modifyRelay(_relay, _callers, _jobsData);

    (, IAutomationVault.JobData[] memory _relayJobsData) = automationVault.getRelayDataForTest(_relay);

    assertEq(_relayJobsData.length, 2);
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
    _assumeRelayData(_relay, _callers, makeAddr('job'), new bytes4[](1));

    automationVault.addRelayForTest(_relay, new address[](0), address(0), new bytes4[](0));

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
  using EnumerableSet for EnumerableSet.Bytes32Set;

  EnumerableSet.Bytes32Set internal _cleanSelectors;

  modifier happyPath(address _relay, address _job, bytes4[] memory _selectors) {
    /// @dev This is a workaround for the fact that the VM does not support dynamic arrays
    _assumeRelayData(_relay, new address[](1), _job, _selectors);

    automationVault.addRelayForTest(_relay, new address[](0), address(0), new bytes4[](1));

    for (uint256 _i; _i < _selectors.length; ++_i) {
      _cleanSelectors.add(_selectors[_i]);
    }

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
  function testRelayJobsAndSelectorsAreModified(
    address _relay,
    address _job,
    bytes4[] memory _selectors
  ) public happyPath(_relay, _job, _selectors) {
    // Get the list of jobs data for the relay
    (, IAutomationVault.JobData[] memory _jobsData) = automationVault.getRelayDataForTest(_relay);

    // Length should be zero
    assertEq(_jobsData.length, 0);

    _jobsData = _createJobsData(_job, _selectors);

    // Modify the relay jobs
    automationVault.modifyRelayJobs(_relay, _jobsData);

    // Get the list of jobs data for the relay
    (, _jobsData) = automationVault.getRelayDataForTest(_relay);

    for (uint256 _i; _i < _jobsData.length; ++_i) {
      assertEq(_jobsData[_i].job, _job);
      assertEq(_jobsData[_i].functionSelectors.length, _cleanSelectors.length());

      for (uint256 _j; _j < _jobsData[_i].functionSelectors.length; ++_j) {
        assertEq(_jobsData[_i].functionSelectors[_j], _cleanSelectors.at(_j));
      }
    }
  }

  /**
   * @notice Emit ApproveJob and ApproveJobSelector events when the relay is modified
   */
  function testEmitApproveJobAndSelector(
    address _relay,
    address _job,
    bytes4[] memory _selectors
  ) public happyPath(_relay, _job, _selectors) {
    IAutomationVault.JobData[] memory _jobsData = _createJobsData(_job, _selectors);

    vm.expectEmit();
    emit ApproveJob(_job);

    for (uint256 _i; _i < _cleanSelectors.length(); ++_i) {
      vm.expectEmit();
      emit ApproveJobSelector(_job, bytes4(_cleanSelectors.at(_i)));
    }

    automationVault.modifyRelayJobs(_relay, _jobsData);
  }

  /**
   * @notice Test modify relay jobs with several jobs
   * @dev Isolated test to check that more than one job is added
   */
  function testModifyRelayJobsWithSeveralJobs(
    address _relay,
    address[] memory _callers,
    address _job,
    bytes4[] memory _selectors,
    address _secondJob,
    bytes4[] memory _secondSelectors
  ) public {
    _assumeRelayData(_relay, _callers, _job, _selectors);
    vm.assume(_job != address(0));
    vm.assume(_secondJob != address(0));
    vm.assume(_job != _secondJob);

    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](2);
    _jobsData[0].job = _job;
    _jobsData[0].functionSelectors = _selectors;
    _jobsData[1].job = _secondJob;
    _jobsData[1].functionSelectors = _secondSelectors;

    vm.prank(owner);
    automationVault.modifyRelayJobs(_relay, _jobsData);

    (, IAutomationVault.JobData[] memory _relayJobsData) = automationVault.getRelayDataForTest(_relay);

    assertEq(_relayJobsData.length, 2);
  }
}

contract UnitAutomationVaultExec is AutomationVaultUnitTest {
  modifier happyPath(
    address _relay,
    address _caller,
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) {
    vm.assume(_execData.length > 3 && _feeData.length > 3);
    vm.assume(_execData.length < 30 && _feeData.length < 30);

    // Add the relay caller
    automationVault.addRelayCallerForTest(_relay, _caller);

    // Add the job and the selector
    for (uint256 _i; _i < _execData.length; ++_i) {
      automationVault.addJobSelectorForTest(_relay, _execData[_i].job, bytes4(_execData[_i].jobData));
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
   * @notice Checks that the test has to revert if the caller is not the relay caller
   */
  function testRevertIfNotApprovedRelayCaller(
    address _relay,
    address _caller,
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relay, _caller, _execData, _feeData) {
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
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relay, _caller, _execData, _feeData) {
    _execData[0].jobData = '0xdead';

    vm.expectRevert(IAutomationVault.AutomationVault_NotApprovedJobSelector.selector);
    automationVault.exec(_caller, _execData, _feeData);
  }

  /**
   * @notice Checks that the test has to revert if the job call failed
   */
  function testRevertIfJobCallFailed(
    address _relay,
    address _caller,
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relay, _caller, _execData, _feeData) {
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
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relay, _caller, _execData, _feeData) {
    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.expectCall(_execData[_i].job, _execData[_i].jobData, 1);
    }

    automationVault.exec(_caller, _execData, new IAutomationVault.FeeData[](0));
  }

  /**
   * @notice Checks that call is executed correctly with fees
   */
  function testCallJobFunction(
    address _relay,
    address _caller,
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relay, _caller, _execData, _feeData) {
    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.expectCall(_execData[_i].job, _execData[_i].jobData, 1);
    }

    automationVault.exec(_caller, _execData, _feeData);
  }

  /**
   * @notice Checks that call is executed correctly with fees and open sender
   */
  function testCallJobFunctionWithOpenSender(
    address _relay,
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData,
    address _sender
  ) public happyPath(_relay, _ALL, _execData, _feeData) {
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
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relay, _caller, _execData, _feeData) {
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
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relay, _caller, _execData, _feeData) {
    _feeData[1].feeToken = _NATIVE_TOKEN;
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
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData,
    uint128 _fee
  ) public happyPath(_relay, _caller, _execData, _feeData) {
    for (uint256 _i; _i < _feeData.length; ++_i) {
      _feeData[_i].feeToken = _NATIVE_TOKEN;
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
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relay, _caller, _execData, _feeData) {
    for (uint256 _i; _i < _feeData.length; ++_i) {
      vm.assume(_feeData[_i].feeToken != _NATIVE_TOKEN);
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
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_relay, _caller, _execData, _feeData) {
    for (uint256 _i; _i < _feeData.length; ++_i) {
      vm.expectEmit();
      emit IssuePayment(_relay, _caller, _feeData[_i].feeRecipient, _feeData[_i].feeToken, _feeData[_i].fee);
    }

    automationVault.exec(_caller, _execData, _feeData);
  }
}
