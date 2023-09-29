// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {CommonE2ETest} from '@test/e2e/Common.t.sol';

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';

contract E2EOpenRelay is CommonE2ETest {
  function setUp() public override {
    CommonE2ETest.setUp();

    // AutomationVault setup
    address[] memory _bots = new address[](1);
    _bots[0] = bot;
    bytes4[] memory _jobFunctions = new bytes4[](2);
    _jobFunctions[0] = basicJob.work.selector;
    _jobFunctions[1] = basicJob.workHard.selector;

    startHoax(owner);
    automationVault.approveRelayCallers(address(openRelay), _bots);
    automationVault.approveJobSelectors(address(basicJob), _jobFunctions);
    address(automationVault).call{value: 100 ether}('');
    vm.stopPrank();
  }

  function test_execute_job() public {
    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.work.selector));

    vm.expectEmit(address(basicJob));
    emit Worked();

    vm.prank(bot);
    openRelay.exec(address(automationVault), _execData, bot);
  }

  function test_issue_payment(uint16 _howHard) public {
    vm.assume(_howHard <= 1000);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] =
      IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.workHard.selector, _howHard));

    vm.prank(bot);
    uint256 _gasBeforeExec = gasleft();
    openRelay.exec(address(automationVault), _execData, bot);
    uint256 _gasAfterExec = gasleft();

    uint256 _txCost = (_gasBeforeExec - _gasAfterExec) * block.basefee;
    uint256 _payment = _txCost * openRelay.GAS_MULTIPLIER() / openRelay.BASE();

    assertGt(bot.balance, _payment);
    assertLt(bot.balance, _payment * openRelay.GAS_MULTIPLIER() / openRelay.BASE());
  }
}
