// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {IXKeeperMetadata, XKeeperMetadata, IAutomationVault} from '@contracts/XKeeperMetadata.sol';

/**
 * @title XKeeperMetadata Unit tests
 */
contract XKeeperMetadataUnitTest is Test {
  // Events
  event AutomationVaultMetadataSetted(IAutomationVault indexed _automationVault, string _description);

  // XKeeperMetadata contract
  XKeeperMetadata public xKeeperMetadata;

  // EOAs
  address public owner;

  function setUp() public virtual {
    xKeeperMetadata = new XKeeperMetadata();
    owner = makeAddr('Owner');
  }
}

contract UnitXKeeperMetadataSetAutomationVaultMetadata is XKeeperMetadataUnitTest {
  modifier happyPath(IAutomationVault _automationVault, string calldata _description) {
    vm.mockCall(address(_automationVault), abi.encodeWithSelector(IAutomationVault.owner.selector), abi.encode(owner));
    vm.startPrank(owner);
    _;
  }

  function testRevertInlyAutomationVaultOwner(
    IAutomationVault _automationVault,
    string calldata _description
  ) public happyPath(_automationVault, _description) {
    vm.expectRevert(IXKeeperMetadata.XKeeperMetadata_OnlyAutomationVaultOwner.selector);

    changePrank(makeAddr('NotOwner'));
    xKeeperMetadata.setAutomationVaultMetadata(_automationVault, _description);
  }

  function testSetAutomationVaultMetadata(
    IAutomationVault _automationVault,
    string calldata _description
  ) public happyPath(_automationVault, _description) {
    xKeeperMetadata.setAutomationVaultMetadata(_automationVault, _description);

    assertEq(xKeeperMetadata.automationVaultMetadata(_automationVault), _description);
  }

  function testEmitAutomationVaultMetadataSetted(
    IAutomationVault _automationVault,
    string calldata _description
  ) public happyPath(_automationVault, _description) {
    vm.expectEmit();
    emit AutomationVaultMetadataSetted(_automationVault, _description);

    xKeeperMetadata.setAutomationVaultMetadata(_automationVault, _description);
  }
}
