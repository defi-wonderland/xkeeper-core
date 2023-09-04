// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {AutomationVault, IAutomationVault} from '@contracts/AutomationVault.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';

contract AutomationVaultForTest is AutomationVault {
  function setJobOwnerForTest(address _job, address _jobOwner) public {
    jobOwner[_job] = _jobOwner;
  }

  function setJobApprovedRelaysForTest(address _job, bytes4 _jobSelector, address _relay, bool _approved) public {
    jobApprovedRelays[_job][_jobSelector][_relay] = _approved;
  }

  function setJobsBalancesForTest(address _job, address _token, uint256 _balance) public {
    jobsBalances[_job][_token] = _balance;
  }
}

/**
 * @title AutomationVault Unit tests
 */
abstract contract AutomationVaultUnitTest is Test {
  // Events
  event RegisterJob(address indexed _job, address indexed _jobOwner);
  event DepositFunds(address indexed _job, address indexed _token, uint256 _amount);
  event WithdrawFunds(address indexed _job, address indexed _token, uint256 _amount, address indexed _receiver);
  event ApproveRelay(address indexed _job, bytes4 _jobSelector, address indexed _relay);
  event RevokeRelay(address indexed _job, bytes4 _jobSelector, address indexed _relay);
  event IssuePayment(
    address indexed _job, bytes4 _jobSelector, uint256 _fee, address indexed _feeToken, address indexed _feeRecipient
  );

  // AutomationVault contract
  AutomationVaultForTest public automationVault;

  // Mock contracts
  address public token;
  address public job;
  address public relay;

  // EOAs
  address public jobOwner;
  address public jobPendingOwner;
  address public receiver;

  // Data
  address public eth;
  bytes4 public jobSelector;

  function setUp() public virtual {
    eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    jobSelector = bytes4(keccak256('jobSelector()'));

    jobOwner = makeAddr('JobOwner');
    jobPendingOwner = makeAddr('JobPendingOwner');
    receiver = makeAddr('Receiver');

    token = makeAddr('Token');
    job = makeAddr('Job');
    relay = makeAddr('Relay');

    automationVault = new AutomationVaultForTest();
  }

  function _mockTokenTransfer(address _token) internal {
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
  }
}

contract UnitAutomationVaultRegisterJob is AutomationVaultUnitTest {
  function testRevertIfJobAlreadyRegisted(address _fakeOwner) public {
    automationVault.setJobOwnerForTest(job, jobOwner);
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_JobAlreadyRegistered.selector, jobOwner));

    automationVault.registerJob(job, _fakeOwner);
  }

  function testJobIsRegisteredCorrectly(address _jobOwner) public {
    automationVault.registerJob(job, _jobOwner);
    assertEq(automationVault.jobOwner(job), _jobOwner);
  }

  function testEmitRegisterJob(address _jobOwner) public {
    vm.expectEmit();
    emit RegisterJob(job, _jobOwner);

    automationVault.registerJob(job, _jobOwner);
  }
}

contract UnitAutomationVaultDepositFunds is AutomationVaultUnitTest {
  function setUp() public virtual override {
    super.setUp();
    vm.deal(jobOwner, 2 ** 256 - 1);
  }

  function testRevertReceive(uint128 _ethAmount) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_ReceiveETHNotAvailable.selector));
    vm.prank(jobOwner);

    // solhint-disable-next-line
    address(automationVault).call{value: _ethAmount}('');
  }

  function testRevertIfInvalidETHValue(uint128 _amount, uint128 _ethAmount) public {
    vm.assume(_amount != _ethAmount);
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_InvalidAmount.selector));
    vm.prank(jobOwner);
    automationVault.depositFunds{value: _ethAmount}(job, eth, _amount);
  }

  function testDepositETHBalance(uint128 _amount, uint128 _ethAmount) public {
    vm.assume(_amount == _ethAmount);

    vm.prank(jobOwner);
    automationVault.depositFunds{value: _ethAmount}(job, eth, _amount);

    assertEq(address(automationVault).balance, _ethAmount);
  }

  function testEmitDepositInETH(uint128 _amount, uint128 _ethAmount) public {
    vm.assume(_amount == _ethAmount);

    vm.expectEmit();
    emit DepositFunds(job, eth, _amount);

    vm.prank(jobOwner);
    automationVault.depositFunds{value: _ethAmount}(job, eth, _amount);
  }

  function testEmitDepositInERC20(uint128 _amount) public {
    vm.expectEmit();
    emit DepositFunds(job, token, _amount);

    vm.expectCall(
      token, abi.encodeWithSelector(IERC20.transferFrom.selector, jobOwner, address(automationVault), _amount)
    );
    vm.mockCall(
      token,
      abi.encodeWithSelector(IERC20.transferFrom.selector, jobOwner, address(automationVault), _amount),
      abi.encode(true)
    );

    vm.prank(jobOwner);
    automationVault.depositFunds(job, token, _amount);
  }
}

contract UnitAutomationVaultWithdrawFunds is AutomationVaultUnitTest {
  function setUp() public virtual override {
    super.setUp();
    vm.deal(address(automationVault), 2 ** 256 - 1);
    automationVault.setJobOwnerForTest(job, jobOwner);
  }

  function testRevertIfCallerIsNotOwner(uint128 _amount) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyJobOwner.selector, jobOwner));

    automationVault.withdrawFunds(job, eth, _amount, jobOwner);
  }

  function testRevertIfAmountGreaterThanBalance(uint128 _balance, uint128 _amount) public {
    vm.assume(_amount > _balance);
    automationVault.setJobsBalancesForTest(job, token, _balance);

    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_InsufficientFunds.selector));

    vm.prank(jobOwner);
    automationVault.withdrawFunds(job, token, _amount, receiver);
  }

  function testRevertIfETHTransferFailed(uint128 _balance, uint128 _amount) public {
    vm.assume(_balance > _amount && _amount > 0);
    automationVault.setJobsBalancesForTest(job, eth, _balance);

    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_ETHTransferFailed.selector));

    vm.prank(jobOwner);
    automationVault.withdrawFunds(job, eth, _amount, address(automationVault));
  }

  function testWithdrawETHAmountUpdateBalances(uint128 _balance, uint128 _amount) public {
    vm.assume(_balance > _amount && _amount > 0);
    automationVault.setJobsBalancesForTest(job, eth, _balance);

    vm.prank(jobOwner);
    automationVault.withdrawFunds(job, eth, _amount, receiver);

    assertEq(receiver.balance, _amount);
    assertEq(automationVault.jobsBalances(job, eth), _balance - _amount);
  }

  function testEmitWithdrawETHAmount(uint128 _balance, uint128 _amount) public {
    vm.assume(_balance > _amount && _amount > 0);
    automationVault.setJobsBalancesForTest(job, eth, _balance);

    vm.expectEmit();
    emit WithdrawFunds(job, eth, _amount, receiver);

    vm.prank(jobOwner);
    automationVault.withdrawFunds(job, eth, _amount, receiver);
  }

  function testEmitWithdrawERC2OAmount(uint128 _balance, uint128 _amount) public {
    vm.assume(_balance > _amount && _amount > 0);
    automationVault.setJobsBalancesForTest(job, token, _balance);

    vm.expectEmit();
    emit WithdrawFunds(job, token, _amount, receiver);

    vm.expectCall(token, abi.encodeWithSelector(IERC20.transfer.selector, receiver, _amount));
    vm.mockCall(token, abi.encodeWithSelector(IERC20.transfer.selector, receiver, _amount), abi.encode(true));

    vm.prank(jobOwner);
    automationVault.withdrawFunds(job, token, _amount, receiver);
  }
}

contract UnitAutomationVaultApproveRelay is AutomationVaultUnitTest {
  function setUp() public override {
    AutomationVaultUnitTest.setUp();

    automationVault.setJobOwnerForTest(job, jobOwner);

    vm.startPrank(jobOwner);
  }

  function testRevertIfCallerIsNotOwner(bytes4 _jobSelector, address _relay) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyJobOwner.selector, jobOwner));

    changePrank(jobPendingOwner);
    automationVault.approveRelay(job, _jobSelector, _relay);
  }

  function testRevertIfAlreadyApprovedRelay(bytes4 _jobSelector, address _relay) public {
    automationVault.setJobApprovedRelaysForTest(job, _jobSelector, _relay, true);

    vm.expectRevert(IAutomationVault.AutomationVault_AlreadyApprovedRelay.selector);

    automationVault.approveRelay(job, _jobSelector, _relay);
  }

  function testSetJobApprovedRelays(bytes4 _jobSelector, address _relay) public {
    automationVault.approveRelay(job, _jobSelector, _relay);

    assertTrue(automationVault.jobApprovedRelays(job, _jobSelector, _relay));
  }

  function testEmitApproveRelay(bytes4 _jobSelector, address _relay) public {
    vm.expectEmit();
    emit ApproveRelay(job, _jobSelector, _relay);

    automationVault.approveRelay(job, _jobSelector, _relay);
  }
}

contract UnitAutomationVaultRevokeRelay is AutomationVaultUnitTest {
  function setUp() public override {
    AutomationVaultUnitTest.setUp();

    automationVault.setJobOwnerForTest(job, jobOwner);
    automationVault.setJobApprovedRelaysForTest(job, jobSelector, relay, true);

    vm.startPrank(jobOwner);
  }

  function testRevertIfCallerIsNotOwner() public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyJobOwner.selector, jobOwner));

    changePrank(jobPendingOwner);
    automationVault.revokeRelay(job, jobSelector, relay);
  }

  function testRevertIfNotApprovedRelay(address _relayToRevoke) public {
    vm.assume(_relayToRevoke != relay);

    vm.expectRevert(IAutomationVault.AutomationVault_NotApprovedRelay.selector);

    automationVault.revokeRelay(job, jobSelector, _relayToRevoke);
  }

  function testSetJobApprovedRelays() public {
    automationVault.revokeRelay(job, jobSelector, relay);

    assertFalse(automationVault.jobApprovedRelays(job, jobSelector, relay));
  }

  function testEmitRevokeRelay() public {
    vm.expectEmit();
    emit RevokeRelay(job, jobSelector, relay);

    automationVault.revokeRelay(job, jobSelector, relay);
  }
}

contract UnitAutomationVaultIssuePayment is AutomationVaultUnitTest {
  function setUp() public override {
    AutomationVaultUnitTest.setUp();

    automationVault.setJobApprovedRelaysForTest(job, jobSelector, relay, true);
    automationVault.setJobsBalancesForTest(job, eth, type(uint256).max);
    automationVault.setJobsBalancesForTest(job, token, type(uint256).max);
    _mockTokenTransfer(token);

    deal(address(automationVault), type(uint256).max);

    vm.startPrank(relay);
  }

  function testRevertIfNotApprovedRelay(uint256 _fee) public {
    vm.expectRevert(IAutomationVault.AutomationVault_NotApprovedRelay.selector);

    changePrank(jobOwner);
    automationVault.issuePayment(job, jobSelector, _fee, token, receiver);
  }

  function testRevertIfInsufficientFunds(uint256 _fee, uint256 _jobBalance) public {
    vm.assume(_fee > _jobBalance);
    automationVault.setJobsBalancesForTest(job, token, _jobBalance);

    vm.expectRevert(IAutomationVault.AutomationVault_InsufficientFunds.selector);

    automationVault.issuePayment(job, jobSelector, _fee, token, receiver);
  }

  function testRevertIfETHTransferFailed(uint256 _fee) public {
    vm.expectRevert(IAutomationVault.AutomationVault_ETHTransferFailed.selector);

    automationVault.issuePayment(job, jobSelector, _fee, eth, address(automationVault));
  }

  function testCallETHTransfer(uint256 _fee) public {
    automationVault.issuePayment(job, jobSelector, _fee, eth, receiver);

    assertEq(receiver.balance, _fee);
  }

  function testCallTokenTransfer(uint256 _fee) public {
    vm.expectCall(token, abi.encodeCall(IERC20.transfer, (receiver, _fee)), 1);

    automationVault.issuePayment(job, jobSelector, _fee, token, receiver);
  }

  function testEmitIssuePayment(uint256 _fee) public {
    vm.expectEmit();
    emit IssuePayment(job, jobSelector, _fee, token, receiver);

    automationVault.issuePayment(job, jobSelector, _fee, token, receiver);
  }
}
