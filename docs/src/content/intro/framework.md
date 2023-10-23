# Keep3r Framework

## Why Keep3r Framework?

Keep3r Framework offers a powerful solution for on-chain automation. Here's why you should consider using it:

- **Simplicity**: With the assistance of our relays and vault, you'll be able to easily manage automation for your contracts, and the payment process will be smoother than ever before.

- **Versatility**: Keep3r Framework is built to be compatible with various keeper services, including Keep3r, Gelato, Autonolas, and others. You have the freedom to choose the keeper that best fits your requirements.

- **Public Good**: We're committed to contributing to the blockchain community by offering Keep3r Framework as an open and free resource, promoting automation and efficiency across the ecosystem.

Join us in simplifying on-chain automation with Keep3r Framework.

## Actors

### Automation Vault

The `AutomationVault` is designed to facilitate the management of job execution with various relays and the payment of these relays for their services. The contract operates as a core component in the realm of on-chain automation. It provides a robust and user-friendly solution for defining and executing tasks while ensuring that payments are handled in a more straightforward manner.

#### Features

- **Relay and Job Management**: The `AutomationVault` contract allows users to manage approved relays and jobs efficiently. It maintains a list of approved relays and jobs, providing control over who can perform specific tasks.

- **Simplified Payment Handling**: Payment management has been simplified, allowing payments to be made in a more user-friendly manner. It supports both Ether (ETH) and ERC-20 tokens, ensuring that fees for job execution are processed seamlessly.

- **Ownership Control**: The contract incorporates ownership management to ensure control over its functions. The owner has the authority to approve or revoke relays, callers, and selectors.

- **Flexibility**: Users have the freedom to add or remove relays and select specific functions to be executed by jobs, granting them greater control over their automation processes.

### Open Relay

The `OpenRelay` is designed to manage and facilitate the execution of tasks coming from various bots, ensuring efficient automation processes and fee payments. This contract plays a crucial role in the broader ecosystem of on-chain automation.
