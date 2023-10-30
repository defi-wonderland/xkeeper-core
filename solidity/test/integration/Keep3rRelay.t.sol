// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {CommonIntegrationTest} from '@test/integration/Common.t.sol';

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';
import {IKeep3rV2} from '@interfaces/external/IKeep3rV2.sol';
import {IKeep3rHelper} from '@interfaces/external/IKeep3rHelper.sol';
import {IKeep3rV1} from '@interfaces/external/IKeep3rV1.sol';
import {_KEEP3R_V2, _KEEP3R_V2_HELPER, _KEEP3R_V1, _KEEP3R_GOVERNOR} from '@utils/Constants.sol';

contract IntegrationKeep3rRelay is CommonIntegrationTest {
  // Events
  event KeeperValidation(uint256 _gasLeft);
  event KeeperWork(
    address indexed _credit, address indexed _job, address indexed _keeper, uint256 _amount, uint256 _gasLeft
  );

  // Keep3r contracts
  IKeep3rV2 public keep3r;
  IKeep3rHelper public keep3rHelper;
  IKeep3rV1 public kp3r;

  uint256 public constant GAS_BONUS = 53_000;

  // EOAs
  address public keep3rGovernor;

  function setUp() public override {
    CommonIntegrationTest.setUp();

    // Keep3r setup
    keep3rGovernor = _KEEP3R_GOVERNOR;
    keep3r = IKeep3rV2(_KEEP3R_V2);
    keep3rHelper = IKeep3rHelper(_KEEP3R_V2_HELPER);
    kp3r = IKeep3rV1(_KEEP3R_V1);

    _addJobAndLiquidity(address(automationVault), 1000 ether);
    _bondAndActivateKeeper(bot, 0);

    // AutomationVault setup
    address[] memory _keepers = new address[](1);
    _keepers[0] = bot;
    bytes4[] memory _keep3rSelectors = new bytes4[](2);
    _keep3rSelectors[0] = keep3r.isKeeper.selector;
    _keep3rSelectors[1] = keep3r.worked.selector;
    bytes4[] memory _jobSelectors = new bytes4[](2);
    _jobSelectors[0] = basicJob.work.selector;
    _jobSelectors[1] = basicJob.workHard.selector;

    vm.startPrank(owner);
    automationVault.approveRelayCallers(address(keep3rRelay), _keepers);
    automationVault.approveJobSelectors(address(keep3r), _keep3rSelectors);
    automationVault.approveJobSelectors(address(basicJob), _jobSelectors);

    changePrank(bot);
  }

  function _addJobAndLiquidity(address _job, uint256 _amount) internal {
    keep3r.addJob(_job);

    vm.prank(keep3rGovernor);
    keep3r.forceLiquidityCreditsToJob(_job, _amount);
  }

  function _bondAndActivateKeeper(address _keeper, uint256 _bondAmount) internal {
    vm.startPrank(_keeper);
    kp3r.approve(address(keep3r), _bondAmount);
    keep3r.bond(address(kp3r), _bondAmount);

    skip(keep3r.bondTime() + 1);

    keep3r.activate(address(kp3r));
    vm.stopPrank();
  }

  function test_execute_job_keep3r() public {
    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.work.selector));

    vm.expectEmit(true, true, true, false, address(keep3r));
    emit KeeperValidation(0);
    vm.expectEmit(address(basicJob));
    emit Worked();
    vm.expectEmit(true, true, true, false, address(keep3r));
    emit KeeperWork(address(kp3r), address(automationVault), bot, 0, 0);

    keep3rRelay.exec(address(automationVault), _execData);
  }

  function test_issue_payment_keep3r_low_base_fee_diff(uint64 _fee, uint16 _howHard) public {
    vm.assume(_howHard > 35 && _howHard <= 100);
    vm.assume(_fee > 0 && _fee <= keep3rHelper.minBaseFee() - keep3rHelper.minPriorityFee());
    vm.fee(_fee);

    uint256 _payment = keep3r.bonds(bot, address(kp3r));
    assertEq(_payment, 0);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] =
      IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.workHard.selector, _howHard));

    uint256 _gasBeforeExec = gasleft();
    keep3rRelay.exec(address(automationVault), _execData);
    uint256 _gasAfterExec = gasleft();

    uint256 _gasPrice = keep3rHelper.minPriorityFee() + _fee;
    uint256 _txCost = (_gasBeforeExec - _gasAfterExec) * _gasPrice;

    uint256 _breakEven = keep3rHelper.quote(_txCost) * keep3rHelper.minBoost() / keep3rHelper.BOOST_BASE();

    _payment = keep3r.bonds(bot, address(kp3r));

    assertGt(_payment, _breakEven * 11 / 10, 'the keeper should earn more than 110% of the cost');
    assertLt(_payment, _breakEven * 115 / 100, 'the keeper should earn less than 115% of the cost');
  }

  function test_issue_payment_keep3r_high_base_fee_DIFF(uint16 _howHard) public {
    vm.assume(_howHard > 80 && _howHard <= 100);
    vm.fee(50 gwei); // >= keep3rHelper.minBaseFee() - keep3rHelper.minPriorityFee()

    uint256 _payment = keep3r.bonds(bot, address(kp3r));
    assertEq(_payment, 0);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] =
      IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.workHard.selector, _howHard));

    keep3rRelay.exec(address(automationVault), _execData); // Initializes storage variables
    _payment = keep3r.bonds(bot, address(kp3r));

    uint256 _gasBeforeExec = gasleft() * 63 / 64; // Gas measurements with EIP-150
    keep3rRelay.exec(address(automationVault), _execData);
    uint256 _gasAfterExec = gasleft() * 63 / 64;

    uint256 _txCost = (_gasBeforeExec - _gasAfterExec + GAS_BONUS) * keep3rHelper.minBaseFee();
    uint256 _breakEven = keep3rHelper.quote(_txCost);

    _payment = keep3r.bonds(bot, address(kp3r)) - _payment;
    assertGt(_payment, _breakEven * 11 / 10, 'the keeper should earn more than 110% of the cost');
    assertLt(_payment, _breakEven * 115 / 100, 'the keeper should earn less than 115% of the cost');
  }
}
