pragma solidity 0.8.19;

interface IKeep3rSponsor {
  error KeeperNotValid();
  error KeeperNotWorked();
  error JobNotSponsored();

  event JobExecuted(address job);
}
