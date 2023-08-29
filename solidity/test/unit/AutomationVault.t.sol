// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {IAutomationVault, AutomationVault, IERC20} from '@contracts/AutomationVault.sol';

contract AutomationVaultForTest is AutomationVault {
  function setJobOwnerForTest(address _job, address _owner) public {
    jobOwner[_job] = _owner;
  }

  function setJobsBalancesForTest(address _job, address _token, uint256 _amount) public {
    jobsBalances[_job][_token] = _amount;
  }
}

/**
 * @title AutomationVault Unit tests
 */
contract AutomationVaultUnitTest is Test {
  using stdStorage for StdStorage;

  // Events tested
  event DepositFunds(address indexed _job, address indexed _token, uint256 _amount);
  event WithdrawFunds(address indexed _job, address indexed _token, uint256 _amount, address indexed _receiver);

  // ETH address
  address public eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  // The target contract
  AutomationVaultForTest public automationVault;

  // Mock deposit token
  address public token;

  // Mock Owner
  address public owner;

  // Mock Receiver
  address public receiver;

  // Mock Job
  address public job;

  function setUp() public virtual {
    token = makeAddr('Token');

    owner = makeAddr('Owner');

    receiver = makeAddr('Receiver');

    job = makeAddr('Token');

    automationVault = new AutomationVaultForTest();
  }
}

contract UnitAutomationVaultDepositFunds is AutomationVaultUnitTest {
  function setUp() public virtual override {
    super.setUp();
    vm.deal(owner, 2 ** 256 - 1);
  }

  function testRevertReceive(uint128 _ethAmount) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_ReceiveEthNotAvailable.selector));
    vm.prank(owner);

    // solhint-disable-next-line
    address(automationVault).call{value: _ethAmount}('');
  }

  function testRevertIfInvalidETHValue(uint128 _amount, uint128 _ethAmount) public {
    vm.assume(_amount != _ethAmount);
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_InvalidAmount.selector));
    vm.prank(owner);
    automationVault.depositFunds{value: _ethAmount}(job, eth, _amount);
  }

  function testDepositETHBalance(uint128 _amount, uint128 _ethAmount) public {
    vm.assume(_amount == _ethAmount);

    vm.prank(owner);
    automationVault.depositFunds{value: _ethAmount}(job, eth, _amount);

    assertEq(address(automationVault).balance, _ethAmount);
  }

  function testEmitDepositInETH(uint128 _amount, uint128 _ethAmount) public {
    vm.assume(_amount == _ethAmount);

    vm.expectEmit();
    emit DepositFunds(job, eth, _amount);

    vm.prank(owner);
    automationVault.depositFunds{value: _ethAmount}(job, eth, _amount);
  }

  function testEmitDepositInERC20(uint128 _amount) public {
    vm.expectEmit();
    emit DepositFunds(job, token, _amount);

    vm.expectCall(token, abi.encodeWithSelector(IERC20.transferFrom.selector, owner, address(automationVault), _amount));
    vm.mockCall(
      token,
      abi.encodeWithSelector(IERC20.transferFrom.selector, owner, address(automationVault), _amount),
      abi.encode(true)
    );

    vm.prank(owner);
    automationVault.depositFunds(job, token, _amount);
  }
}

contract UnitAutomationVaultWithdrawFunds is AutomationVaultUnitTest {
  function setUp() public virtual override {
    super.setUp();
    vm.deal(address(automationVault), 2 ** 256 - 1);
    automationVault.setJobOwnerForTest(job, owner);
  }

  function testIfOwnerIsNotTheCaller(uint128 _amount) public {
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyJobOwner.selector, owner));

    automationVault.withdrawFunds(job, eth, _amount, owner);
  }

  function testRevertIfAmountGreaterThanBalance(uint128 _balance, uint128 _amount) public {
    vm.assume(_amount > _balance);
    automationVault.setJobsBalancesForTest(job, token, _balance);

    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_InvalidAmount.selector));

    vm.prank(owner);
    automationVault.withdrawFunds(job, token, _amount, receiver);
  }

  function testRevertIfETHTransferFailed(uint128 _balance, uint128 _amount) public {
    vm.assume(_balance > _amount && _amount > 0);
    automationVault.setJobsBalancesForTest(job, eth, _balance);

    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_EthTransferFailed.selector));

    vm.prank(owner);
    automationVault.withdrawFunds(job, eth, _amount, address(automationVault));
  }

  function testWithdrawETHAmountUpdateBalances(uint128 _balance, uint128 _amount) public {
    vm.assume(_balance > _amount && _amount > 0);
    automationVault.setJobsBalancesForTest(job, eth, _balance);

    vm.prank(owner);
    automationVault.withdrawFunds(job, eth, _amount, receiver);

    assertEq(receiver.balance, _amount);
    assertEq(automationVault.jobsBalances(job, eth), _balance - _amount);
  }

  function testEmitWithdrawETHAmount(uint128 _balance, uint128 _amount) public {
    vm.assume(_balance > _amount && _amount > 0);
    automationVault.setJobsBalancesForTest(job, eth, _balance);

    vm.expectEmit();
    emit WithdrawFunds(job, eth, _amount, receiver);

    vm.prank(owner);
    automationVault.withdrawFunds(job, eth, _amount, receiver);
  }

  function testEmitWithdrawERC2OAmount(uint128 _balance, uint128 _amount) public {
    vm.assume(_balance > _amount && _amount > 0);
    automationVault.setJobsBalancesForTest(job, token, _balance);

    vm.expectEmit();
    emit WithdrawFunds(job, token, _amount, receiver);

    vm.expectCall(token, abi.encodeWithSelector(IERC20.transfer.selector, receiver, _amount));
    vm.mockCall(token, abi.encodeWithSelector(IERC20.transfer.selector, receiver, _amount), abi.encode(true));

    vm.prank(owner);
    automationVault.withdrawFunds(job, token, _amount, receiver);
  }
}
