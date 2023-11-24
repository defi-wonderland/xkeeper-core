// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {IXKeeperMetadata, XKeeperMetadata, IAutomationVault} from '@contracts/XKeeperMetadata.sol';

/**
 * @title XKeeperMetadata Unit tests
 */
contract XKeeperMetadataUnitTest is Test {
  // Events
  event AutomationVaultMetadataSetted(IAutomationVault indexed _automationVault, string _name, string _description);

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
  modifier happyPath(IAutomationVault _automationVault) {
    vm.mockCall(address(_automationVault), abi.encodeWithSelector(IAutomationVault.owner.selector), abi.encode(owner));
    vm.startPrank(owner);
    _;
  }

  function testRevertOnlyAutomationVaultOwner(
    IAutomationVault _automationVault,
    IXKeeperMetadata.AutomationVaultMetadata calldata _automationVaultMetadata,
    address _newOwner
  ) public happyPath(_automationVault) {
    vm.assume(_newOwner != owner);
    vm.expectRevert(IXKeeperMetadata.XKeeperMetadata_OnlyAutomationVaultOwner.selector);

    changePrank(_newOwner);
    xKeeperMetadata.setAutomationVaultMetadata(_automationVault, _automationVaultMetadata);
  }

  function testSetAutomationVaultMetadata(
    IAutomationVault _automationVault,
    IXKeeperMetadata.AutomationVaultMetadata calldata _automationVaultMetadata
  ) public happyPath(_automationVault) {
    xKeeperMetadata.setAutomationVaultMetadata(_automationVault, _automationVaultMetadata);
    (string memory _name, string memory _description) = xKeeperMetadata.automationVaultMetadata(_automationVault);

    assertEq(_name, _automationVaultMetadata.name);
    assertEq(_description, _automationVaultMetadata.description);
  }

  function testEmitAutomationVaultMetadataSetted(
    IAutomationVault _automationVault,
    IXKeeperMetadata.AutomationVaultMetadata calldata _automationVaultMetadata
  ) public happyPath(_automationVault) {
    vm.expectEmit();
    emit AutomationVaultMetadataSetted(
      _automationVault, _automationVaultMetadata.name, _automationVaultMetadata.description
    );

    xKeeperMetadata.setAutomationVaultMetadata(_automationVault, _automationVaultMetadata);
  }
}
