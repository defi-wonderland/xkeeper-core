// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {IXKeeperMetadata, XKeeperMetadata, IAutomationVault} from '@contracts/XKeeperMetadata.sol';

contract XKeeperMetadataForTest is XKeeperMetadata {
  function addMetadataForTest(
    IAutomationVault[] calldata _automationVaults,
    IXKeeperMetadata.AutomationVaultMetadata[] calldata _automationVaultMetadata
  ) public {
    for (uint256 _index; _index < _automationVaultMetadata.length; _index++) {
      automationVaultMetadata[IAutomationVault(_automationVaults[_index])] = _automationVaultMetadata[_index];
    }
  }
}

/**
 * @title XKeeperMetadata Unit tests
 */
contract XKeeperMetadataUnitTest is Test {
  // Events
  event AutomationVaultMetadataSetted(IAutomationVault indexed _automationVault, string _name, string _description);

  // XKeeperMetadata contract
  XKeeperMetadataForTest public xKeeperMetadata;

  // EOAs
  address public owner;

  function setUp() public virtual {
    xKeeperMetadata = new XKeeperMetadataForTest();
    owner = makeAddr('Owner');
  }
}

contract UnitXKeeperMetadataGetMetadata is XKeeperMetadataUnitTest {
  modifier happyPath(
    IAutomationVault[] calldata _automationVaults,
    IXKeeperMetadata.AutomationVaultMetadata[] calldata _metadata
  ) {
    vm.assume(_automationVaults.length > 0 && _automationVaults.length < 30);
    vm.assume(_automationVaults.length > _metadata.length);

    xKeeperMetadata.addMetadataForTest(_automationVaults, _metadata);

    _;
  }

  function testGetMetadataFromAutomationVault(
    IAutomationVault[] calldata _automationVaults,
    IXKeeperMetadata.AutomationVaultMetadata[] calldata _metadata
  ) public happyPath(_automationVaults, _metadata) {
    // Get the metadata from the contract
    IXKeeperMetadata.AutomationVaultMetadata[] memory _getMetadata =
      xKeeperMetadata.automationVaultsMetadata(_automationVaults);

    assertEq(_getMetadata.length, _automationVaults.length);
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
