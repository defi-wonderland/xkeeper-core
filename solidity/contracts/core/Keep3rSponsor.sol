pragma solidity 0.8.19;

import {IKeep3rSponsor} from '@interfaces/core/IKeep3rSponsor.sol';

import {IAutomationVault, IOpenRelay} from '@interfaces/relays/IOpenRelay.sol';
import {IKeep3rV2} from '@interfaces/external/IKeep3rV2.sol';
import {_KEEP3R_V2, _ETH} from '@utils/Constants.sol';

import {Ownable} from '@openzeppelin/access/Ownable.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract Keep3rSponsor is Ownable, IKeep3rSponsor {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet private sponsoredJobs;
  IAutomationVault constant VAULT = IAutomationVault(0x255ed36E805aEf7f6ad94e3647fA0aED15dBb14D);
  IOpenRelay constant RELAY = IOpenRelay(0xE8E1b32340f527125721903a3947c937dc72e140);

  constructor() Ownable() {}

  modifier validateAndPayKeeper() {
    if (!_KEEP3R_V2.isKeeper(msg.sender)) revert KeeperNotValid();
    _;
    // @note payment amount is questionable
    _KEEP3R_V2.worked(msg.sender);
  }

  modifier isSponsored(address job) {
    if (!jobSponsored(job)) revert JobNotSponsored();
    _;
  }

  // @note unsure if jobs should also be added to automation vault or if assumed to already be in approvedJobs list
  function addJobs(address[] calldata jobs) public onlyOwner {
    for (uint256 i = 0; i < jobs.length; i++) {
      sponsoredJobs.add(jobs[i]);
    }
  }

  function removeJobs(address[] calldata jobs) public onlyOwner {
    for (uint256 i = 0; i < jobs.length; i++) {
      sponsoredJobs.remove(jobs[i]);
    }
  }

  function jobSponsored(address job) public view returns (bool inSet) {
    inSet = sponsoredJobs.contains(job);
  }

  function exec(IAutomationVault.ExecData[] calldata _execData) external validateAndPayKeeper {
    // @note if _execData holds data for just 1 job, this is unnecessary
    for (uint256 i = 0; i < _execData.length; i++) {
      if (!jobSponsored(_execData[i].job)) revert JobNotSponsored();
      // saves gas to emit here rather than making another for loop
      emit JobExecuted(_execData[i].job);
    }

    RELAY.exec(VAULT, _execData, msg.sender);
  }
}
