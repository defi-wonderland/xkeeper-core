// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {
  Keep3rSponsor,
  IKeep3rSponsor,
  IOpenRelay,
  IAutomationVault,
  EnumerableSet
} from '@contracts/periphery/Keep3rSponsor.sol';
import {IKeep3rV2} from '@interfaces/external/IKeep3rV2.sol';
import {_KEEP3R_V2} from '@utils/Constants.sol';

contract Keep3rSponsorForTest is Keep3rSponsor {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet private _sponsoredJobs;

  constructor(
    address _owner,
    address _feeRecipient,
    IOpenRelay _openRelay
  ) Keep3rSponsor(_owner, _feeRecipient, _openRelay) {}

  function addSponsorJobsForTest(address[] memory _jobs) external {
    for (uint256 _i; _i < _jobs.length;) {
      _sponsoredJobs.add(_jobs[_i]);

      unchecked {
        ++_i;
      }
    }
  }

  function setPendingOwnerForTest(address _pendingOwner) public {
    pendingOwner = _pendingOwner;
  }
}

/**
 * @title Keep3rSponsor Unit tests
 */
contract Keep3rSponsorUnitTest is Test {
  // Events
  event JobExecuted(address _job);
  event ChangeOwner(address indexed _pendingOwner);
  event AcceptOwner(address indexed _owner);
  event FeeRecipientSetted(address indexed _feeRecipient);
  event OpenRelaySetted(IOpenRelay indexed _openRelay);
  event ApproveSponsoredJob(address indexed _job);
  event DeleteSponsoredJob(address indexed _job);

  // Keep3rSponsor contract
  Keep3rSponsorForTest public keep3rSponsor;

  IOpenRelay public openRelay;

  /// EOAs
  address public owner;
  address public pendingOwner;
  address public feeRecipient;

  function setUp() public virtual {
    owner = makeAddr('Owner');
    pendingOwner = makeAddr('PendingOwner');
    feeRecipient = makeAddr('FeeRecipient');

    openRelay = IOpenRelay(makeAddr('OpenRelay'));

    keep3rSponsor = new Keep3rSponsorForTest(owner, feeRecipient, openRelay);
  }

  /**
   * @notice Helper function to change the prank and expect revert if the caller is not the owner
   */
  function _revertOnlyOwner() internal {
    vm.expectRevert(abi.encodeWithSelector(IKeep3rSponsor.Keep3rSponsor_OnlyOwner.selector));
    changePrank(pendingOwner);
  }
}

contract UnitKeep3rSponsorConstructor is Keep3rSponsorUnitTest {
  function testParamsAreSet() public {
    assertEq(keep3rSponsor.owner(), owner);
    assertEq(keep3rSponsor.feeRecipient(), feeRecipient);
    assertEq(address(keep3rSponsor.openRelay()), address(openRelay));
  }
}

contract UnitKeep3rSponsorGetSponsoredJob is Keep3rSponsorUnitTest {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _cleanJobs;

  modifier happyPath(address[] memory _sponsoredJobs) {
    vm.assume(_sponsoredJobs.length > 0 && _sponsoredJobs.length < 30);
    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _sponsoredJobs.length; ++_i) {
      _cleanJobs.add(_sponsoredJobs[_i]);
    }

    keep3rSponsor.addSponsorJobsForTest(_sponsoredJobs);
    _;
  }

  function testSponsoredJobs(address[] memory _sponsoredJobs) public happyPath(_sponsoredJobs) {
    address[] memory _cleanSponsoredJobs = _cleanJobs.values();
    address[] memory _getSponsoredJobs = keep3rSponsor.getSponsoredJobs();

    assertEq(_cleanSponsoredJobs.length, _getSponsoredJobs.length);

    for (uint256 _i; _i < _cleanSponsoredJobs.length; ++_i) {
      assertEq(_cleanSponsoredJobs[_i], _getSponsoredJobs[_i]);
    }
  }
}

contract UnitKeep3rSponsorChangeOwner is Keep3rSponsorUnitTest {
  function setUp() public override {
    Keep3rSponsorUnitTest.setUp();

    vm.startPrank(owner);
  }

  function testRevertIfCallerIsNotOwner() public {
    _revertOnlyOwner();
    keep3rSponsor.changeOwner(pendingOwner);
  }

  function testSetPendingOwner() public {
    keep3rSponsor.changeOwner(pendingOwner);

    assertEq(keep3rSponsor.pendingOwner(), pendingOwner);
  }

  function testEmitChangeOwner() public {
    vm.expectEmit();
    emit ChangeOwner(pendingOwner);

    keep3rSponsor.changeOwner(pendingOwner);
  }
}

contract UnitKeep3rSponsorAcceptOwner is Keep3rSponsorUnitTest {
  function setUp() public override {
    Keep3rSponsorUnitTest.setUp();

    keep3rSponsor.setPendingOwnerForTest(pendingOwner);

    vm.startPrank(pendingOwner);
  }

  function testRevertIfCallerIsNotPendingOwner() public {
    vm.expectRevert(abi.encodeWithSelector(IKeep3rSponsor.Keep3rSponsor_OnlyPendingOwner.selector));

    changePrank(owner);
    keep3rSponsor.acceptOwner();
  }

  function testSetJobOwner() public {
    keep3rSponsor.acceptOwner();

    assertEq(keep3rSponsor.owner(), pendingOwner);
  }

  function testDeletePendingOwner() public {
    keep3rSponsor.acceptOwner();

    assertEq(keep3rSponsor.pendingOwner(), address(0));
  }

  function testEmitAcceptOwner() public {
    vm.expectEmit();
    emit AcceptOwner(pendingOwner);

    keep3rSponsor.acceptOwner();
  }
}
