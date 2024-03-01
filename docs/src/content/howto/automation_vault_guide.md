## Tutorial: Deployment and Configuration of Automation Vault

This guide provide all information needed to deploy and configure an `AutomationVault`. You can do it easily using [xkeeper.network](https://xkeeper.network/).

### Step 1: Deployment of the Automation Vault

**Deploy Automation Vault:**

- Use the `AutomationVaultFactory` contract to deploy a new instance of `AutomationVault`. Make sure to provide the owner parameter. The native token will be taken directly from the connected network.

### Step 2: Adding Balance to the Automation Vault

**Transfer Funds to the Vault:**

- Transfer the necessary funds to the automation vault to cover the costs associated with task execution. This could include Native token as ETH in Ethereum network or ERC-20 tokens, depending on the protocol requirements.

### Step 3: Approval of Callers and Relays for a specific relay

**Add relay:**

- Use functions in the automation vault to approve specific relay. This might include relays such as `Keep3rRelay`, `Keep3rBondedRelay`, `GelatoRelay`, or `OpenRelay`, depending on the protocol's needs. The params needed to approve it will be:

    a. The relay address

    b. The callers who will be authorized to call the selected relay.

    c. The Job Data which contains the job and selectors. To enable task executions, you need to approve specific jobs that the automation vault will interact with and will be allowed. Additionally, you need to approve specific function selectors for each approved job. This ensures that only designated functions within the approved jobs can be executed.

### Step 4: Tracking and Monitoring

**Tracking and Monitoring:**

- Monitor task executions through emitted events and other relevant metrics.

With these steps, you should have a solid guide for a protocol to deploy its automation vault, configure necessary permissions and relays, add balance, and execute automated tasks.
