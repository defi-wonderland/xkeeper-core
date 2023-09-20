// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {AutomationVault, IAutomationVault, EnumerableSet} from '@contracts/AutomationVault.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {_ETH, _NULL} from '@contracts/utils/Constants.sol';

contract AutomationVaultForTest is AutomationVault {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(address _owner, string memory _organizationName) AutomationVault(_owner, _organizationName) {}

  function setPendingOwnerForTest(address _pendingOwner) public {
    pendingOwner = _pendingOwner;
  }

  function addRelayEnabledCallersForTest(address _relay, address _relayCaller) public {
    _relayEnabledCallers[_relay].add(_relayCaller);
  }

  function addJobEnabledFunctionsForTest(address _job, bytes4 _functionSelector) public {
    _jobEnabledFunctions[_job].add(_functionSelector);
  }

  function removeJobEnabledFunctionsForTest(address _job, bytes4 _functionSelector) public {
    _jobEnabledFunctions[_job].remove(_functionSelector);
  }
}

contract NoFallbackForTest {}

/**
 * @title AutomationVault Unit tests
 */
abstract contract AutomationVaultUnitTest is Test {
  // Events
  event ChangeOwner(address indexed _pendingOwner);
  event AcceptOwner(address indexed _owner);
  event DepositFunds(address indexed _token, uint256 _amount);
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

  // AutomationVault contract
  AutomationVaultForTest public automationVault;

  // Mock contracts
  address public token;
  address public job;
  address public relay;
  address public relayCaller;

  // EOAs
  address public owner;
  address public pendingOwner;
  address public receiver;

  // Data
  string public organizationName;
  bytes4 public jobSelector;
  bytes public jobData;

  function setUp() public virtual {
    organizationName = 'TestOrganization';
    jobSelector = bytes4(keccak256('jobSelector()'));
    jobData = abi.encodeWithSelector(jobSelector, organizationName);

    owner = makeAddr('Owner');
    pendingOwner = makeAddr('PendingOwner');
    receiver = makeAddr('Receiver');

    token = makeAddr('Token');
    job = makeAddr('Job');
    relay = makeAddr('Relay');
    relayCaller = makeAddr('RelayCaller');

    automationVault = new AutomationVaultForTest(owner, organizationName);
  }

  function _mockTokenTransfer(address _token) internal {
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
  }
}

contract UnitAutomationVaultConstructor is AutomationVaultUnitTest {
  function testParamsAreSet() public {
    assertEq(automationVault.owner(), owner);
    assertEq(automationVault.organizationName(), organizationName);
  }
}

contract UnitAutomationVaultChangeOwner is AutomationVaultUnitTest {
  function setUp() public override {
    AutomationVaultUnitTest.setUp();

    vm.startPrank(owner);
  }

  function testRevertIfCallerIsNotOwner() public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector, owner));

    changePrank(pendingOwner);
    automationVault.changeOwner(pendingOwner);
  }

  function testSetPendingOwner() public {
    automationVault.changeOwner(pendingOwner);

    assertEq(automationVault.pendingOwner(), pendingOwner);
  }

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

  function testRevertIfCallerIsNotPendingOwner() public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyPendingOwner.selector, pendingOwner));

    changePrank(owner);
    automationVault.acceptOwner();
  }

  function testSetJobOwner() public {
    automationVault.acceptOwner();

    assertEq(automationVault.owner(), pendingOwner);
  }

  function testDeletePendingOwner() public {
    automationVault.acceptOwner();

    assertEq(automationVault.pendingOwner(), address(0));
  }

  function testEmitAcceptOwner() public {
    vm.expectEmit();
    emit AcceptOwner(pendingOwner);

    automationVault.acceptOwner();
  }
}

contract UnitAutomationVaultWithdrawFunds is AutomationVaultUnitTest {
  function setUp() public virtual override {
    super.setUp();
    vm.deal(address(automationVault), 2 ** 128 - 1);
    vm.startPrank(owner);
  }

  function testRevertIfCallerIsNotOwner(uint128 _amount, address _fakeOwner) public {
    vm.assume(_fakeOwner != owner);
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector, owner));

    changePrank(_fakeOwner);
    automationVault.withdrawFunds(_ETH, _amount, owner);
  }

  function testRevertIfETHTransferFailed(uint160 _amount) public {
    vm.assume(_amount == type(uint160).max);

    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_ETHTransferFailed.selector));

    automationVault.withdrawFunds(_ETH, _amount, address(automationVault));
  }

  function testWithdrawETHAmountUpdateBalances(uint128 _amount) public {
    vm.assume(_amount > 0);

    uint256 _balance = address(automationVault).balance;
    automationVault.withdrawFunds(_ETH, _amount, receiver);

    assertEq(receiver.balance, _amount);
    assertEq(address(automationVault).balance, _balance - _amount);
  }

  function testEmitWithdrawETHAmount(uint128 _balance, uint128 _amount) public {
    vm.assume(_balance > _amount && _amount > 0);

    vm.expectEmit();
    emit WithdrawFunds(_ETH, _amount, receiver);

    automationVault.withdrawFunds(_ETH, _amount, receiver);
  }

  function testEmitWithdrawERC2OAmount(uint128 _balance, uint128 _amount) public {
    vm.assume(_balance > _amount && _amount > 0);

    vm.expectEmit();
    emit WithdrawFunds(token, _amount, receiver);

    _mockTokenTransfer(token);
    vm.mockCall(token, abi.encodeWithSelector(IERC20.transfer.selector, receiver, _amount), abi.encode(true));

    automationVault.withdrawFunds(token, _amount, receiver);
  }
}

contract UnitAutomationVaultApproveRelayCallers is AutomationVaultUnitTest {
  function setUp() public override {
    AutomationVaultUnitTest.setUp();

    vm.startPrank(owner);
  }

  function testRevertIfCallerIsNotOwner(address _relay, address[] memory _callers) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector, owner));

    changePrank(pendingOwner);
    automationVault.approveRelayCallers(_relay, _callers);
  }

  function testEmitApproveRelay(address _relay) public {
    vm.assume(_relay != address(0));
    address[] memory _callers = new address[](2);

    _callers[0] = (owner);
    _callers[1] = (pendingOwner);

    vm.expectEmit();
    emit ApproveRelay(_relay);

    automationVault.approveRelayCallers(_relay, _callers);
  }

  function testEmitApproveCaller(address _relay) public {
    vm.assume(_relay != address(0));
    address[] memory _callers = new address[](2);

    _callers[0] = (owner);
    _callers[1] = (pendingOwner);

    for (uint256 _i; _i < _callers.length; _i++) {
      vm.expectEmit();
      emit ApproveRelayCaller(_relay, _callers[_i]);
    }

    automationVault.approveRelayCallers(_relay, _callers);
  }
}

contract UnitAutomationVaultRevokeRelayCallers is AutomationVaultUnitTest {
  function setUp() public override {
    AutomationVaultUnitTest.setUp();

    automationVault.addRelayEnabledCallersForTest(relay, owner);

    vm.startPrank(owner);
  }

  function testRevertIfCallerIsNotOwner(address _relay, address[] memory _callers) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector, owner));

    changePrank(pendingOwner);
    automationVault.revokeRelayCallers(_relay, _callers);
  }

  function testEmitRevokeRelay() public {
    address[] memory _callers = new address[](1);

    _callers[0] = (owner);

    vm.expectEmit();
    emit RevokeRelay(relay);

    automationVault.revokeRelayCallers(relay, _callers);
  }

  function testEmitRevokeCaller() public {
    automationVault.addRelayEnabledCallersForTest(relay, pendingOwner);
    address[] memory _callers = new address[](1);

    _callers[0] = (owner);

    for (uint256 _i; _i < _callers.length; _i++) {
      vm.expectEmit();
      emit RevokeRelayCaller(relay, _callers[_i]);
    }

    automationVault.revokeRelayCallers(relay, _callers);
  }
}

contract UnitAutomationVaultApproveJobFunctions is AutomationVaultUnitTest {
  function setUp() public override {
    AutomationVaultUnitTest.setUp();

    vm.startPrank(owner);
  }

  function testRevertIfCallerIsNotOwner(address _job, bytes4[] memory _functionSelectors) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector, owner));

    changePrank(pendingOwner);
    automationVault.approveJobFunctions(_job, _functionSelectors);
  }

  function testEmitApproveJob(address _job, bytes4 _functionSelector) public {
    vm.assume(_job != address(0));
    bytes4[] memory _functionSelectors = new bytes4[](2);

    _functionSelectors[0] = jobSelector;
    _functionSelectors[1] = _functionSelector;

    vm.expectEmit();
    emit ApproveJob(_job);

    automationVault.approveJobFunctions(_job, _functionSelectors);
  }

  function testEmitApproveFunctionSelector(address _job, bytes4 _functionSelector) public {
    vm.assume(_job != address(0));
    vm.assume(_functionSelector != jobSelector);
    bytes4[] memory _functionSelectors = new bytes4[](2);

    _functionSelectors[0] = jobSelector;
    _functionSelectors[1] = _functionSelector;

    for (uint256 _i; _i < _functionSelectors.length; _i++) {
      vm.expectEmit();
      emit ApproveJobFunction(_job, _functionSelectors[_i]);
    }

    automationVault.approveJobFunctions(_job, _functionSelectors);
  }
}

contract UnitAutomationVaultRevokeJobFunctions is AutomationVaultUnitTest {
  function setUp() public override {
    AutomationVaultUnitTest.setUp();
    automationVault.addJobEnabledFunctionsForTest(job, jobSelector);
    vm.startPrank(owner);
  }

  function testRevertIfCallerIsNotOwner(address _job, bytes4[] memory _functionSelectors) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector, owner));

    changePrank(pendingOwner);
    automationVault.revokeJobFunctions(_job, _functionSelectors);
  }

  function testEmitRevokeJob() public {
    bytes4[] memory _functionSelectors = new bytes4[](1);

    _functionSelectors[0] = jobSelector;

    vm.expectEmit();
    emit RevokeJob(job);

    automationVault.revokeJobFunctions(job, _functionSelectors);
  }

  function testEmitRevokeFunctionSelector(address _job, bytes4 _functionSelector) public {
    automationVault.addJobEnabledFunctionsForTest(_job, _functionSelector);
    bytes4[] memory _functionSelectors = new bytes4[](1);

    _functionSelectors[0] = _functionSelector;

    for (uint256 _i; _i < _functionSelectors.length; _i++) {
      vm.expectEmit();
      emit RevokeJobFunction(_job, _functionSelector);
    }

    automationVault.revokeJobFunctions(_job, _functionSelectors);
  }
}

contract UnitAutomationVaultExec is AutomationVaultUnitTest {
  modifier happyPath(IAutomationVault.ExecData[] memory _execData, IAutomationVault.FeeData[] memory _feeData) {
    vm.assume(_execData.length < 30 && _feeData.length < 30);

    automationVault.addRelayEnabledCallersForTest(relay, relayCaller);

    for (uint256 _i; _i < _execData.length; ++_i) {
      automationVault.addJobEnabledFunctionsForTest(_execData[_i].job, bytes4(_execData[_i].jobData));
      assumeNoPrecompiles(_execData[_i].job);
      vm.assume(_execData[_i].job != address(vm));
      vm.mockCall(_execData[_i].job, abi.encodeWithSelector(bytes4(_execData[_i].jobData)), abi.encode());
    }

    for (uint256 _i; _i < _feeData.length; ++_i) {
      assumeNoPrecompiles(_feeData[_i].feeRecipient);
      assumePayable(_feeData[_i].feeRecipient);
      assumeNoPrecompiles(_feeData[_i].feeToken);
      _mockTokenTransfer(_feeData[_i].feeToken);
    }

    deal(address(automationVault), type(uint256).max);

    vm.startPrank(relay);
    _;
  }

  function testRevertIfNotApprovedRelayCaller(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_execData, _feeData) {
    vm.expectRevert(IAutomationVault.AutomationVault_NotApprovedRelayCaller.selector);

    changePrank(owner);
    automationVault.exec(relayCaller, _execData, _feeData);
  }

  function testRevertIfNotApprovedJobFunction(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_execData, _feeData) {
    vm.assume(_execData.length > 3);
    automationVault.removeJobEnabledFunctionsForTest(_execData[1].job, bytes4(_execData[1].jobData));

    vm.expectRevert(IAutomationVault.AutomationVault_NotApprovedJobFunction.selector);

    automationVault.exec(relayCaller, _execData, _feeData);
  }

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

  function testCallJobFunctionWithOpenSender(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData,
    address _sender
  ) public happyPath(_execData, _feeData) {
    vm.assume(_execData.length > 3);
    automationVault.addRelayEnabledCallersForTest(relay, _NULL);

    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.expectCall(_execData[_i].job, _execData[_i].jobData, 1);
    }

    automationVault.exec(_sender, _execData, _feeData);
  }

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

  function testRevertIfETHTransferFailed(
    IAutomationVault.ExecData[] memory _execData,
    IAutomationVault.FeeData[] memory _feeData
  ) public happyPath(_execData, _feeData) {
    vm.assume(_feeData.length > 3);
    _feeData[1].feeToken = _ETH;
    vm.etch(_feeData[1].feeRecipient, type(NoFallbackForTest).runtimeCode);

    vm.expectRevert(IAutomationVault.AutomationVault_ETHTransferFailed.selector);

    automationVault.exec(relayCaller, _execData, _feeData);
  }

  function testCallETHTransfer(
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
