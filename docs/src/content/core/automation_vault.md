# Automation Vault

The `AutomationVault` contract is designed to facilitate the management of job execution with various relays and the payment of these relays for their services. The contract operates as a core component in the realm of on-chain automation. It provides a robust and user-friendly solution for defining and executing tasks while ensuring that payments are handled in a more straightforward manner.

## Key Features

- **Relay and Job Management**: The `AutomationVault` contract allows users to manage approved relays and jobs efficiently. It maintains a list of approved relays and jobs, providing control over who can perform specific tasks.

- **Simplified Payment Handling**: Payment management has been simplified, allowing payments to be made in a more user-friendly manner. It supports both Ether (ETH) and ERC-20 tokens, ensuring that fees for job execution are processed seamlessly.

- **Ownership Control**: The contract incorporates ownership management to ensure control over its functions. The owner has the authority to approve or revoke relays, callers, and selectors.

- **Multichain Support**: The xKeeper core allows to configure the automation vaults for several chains. The native token is configurable for any automation vault.

- **Flexibility**: Users have the freedom to add or remove relays and select specific functions to be executed by jobs, granting them greater control over their automation processes.
