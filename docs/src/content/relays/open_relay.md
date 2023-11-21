# Open Relay

The `OpenRelay` is designed to manage and facilitate the execution of tasks coming from various bots, ensuring efficient automation processes and fee payments.

## Key Features

- **Gas Management**: The contract employs gas management to optimize transaction costs. It calculates the gas spent and provides a gas bonus to ensure that the execution is efficient and cost-effective.

- **Automated Fee Calculation**: The contract automatically calculates and handles fees for task execution. It uses gas metrics to determine the appropriate payment to be made to the automation vault.

- **Seamless Task Execution**: The contract allows the execution of tasks within an automation vault. It ensures that all tasks are carried out smoothly, and fees are promptly paid to the designated fee recipient.

- **Event Transparency**: Upon successful execution, the contract emits the `AutomationVaultExecuted` event, providing transparent insights into executed tasks and relay activities.

## Gas Metrics

- `GAS_BONUS`: 53,000
- `GAS_MULTIPLIER`: 12,000
- `BASE`: 10,000

These gas metrics play a vital role in optimizing gas costs during task execution.
