// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {CommonIntegrationTest} from '@test/integration/Common.t.sol';

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';
import {IERC20, SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {_DAI_WHALE, _DAI, _ETH} from '@utils/Constants.sol';

contract IntegrationAutomationVault is CommonIntegrationTest {
  using SafeERC20 for IERC20;

  // Events
  event ChangeOwner(address indexed _pendingOwner);
  event AcceptOwner(address indexed _owner);

  //EOAs
  address public newOwner;

  function setUp() public override {
    CommonIntegrationTest.setUp();
    newOwner = makeAddr('NewOwner');

    vm.prank(owner);
    address(automationVault).call{value: 100 ether}('');
    _transferDaiToAutomationVault();
  }

  function _transferDaiToAutomationVault() internal {
    vm.prank(_DAI_WHALE);
    IERC20(_DAI).safeTransfer(address(automationVault), 1000);
  }

  function test_changeOwnerAndWithdrawFunds() public {
    // Propose new owner
    vm.prank(owner);
    automationVault.changeOwner(newOwner);

    vm.startPrank(newOwner);
    // Try to withdraw funds, should fail because new owner has not confirmed
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector, owner));
    automationVault.withdrawFunds(_DAI, 1000, newOwner);

    // Balance of DAI should be 0
    assertEq(IERC20(_DAI).balanceOf(newOwner), 0);

    // Confirm new owner and withdraw funds
    automationVault.acceptOwner();
    automationVault.withdrawFunds(_DAI, 1000, newOwner);

    // Check that funds were withdrawn
    assertEq(IERC20(_DAI).balanceOf(newOwner), 1000);

    // Check that the old owner cant withdraw funds
    changePrank(owner);
    vm.expectRevert(abi.encodeWithSelector(IAutomationVault.AutomationVault_OnlyOwner.selector, newOwner));
    automationVault.withdrawFunds(_ETH, 10, owner);
  }
}
