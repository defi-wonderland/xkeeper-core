## Tutorial: Deployment and Configuration of Automation Vault with Relays

### Step 1: Deployment of the Automation Vault

1. **Deploy Automation Vault:**

   - Use the `AutomationVaultFactory` contract to deploy a new instance of `AutomationVault`. Make sure to provide necessary parameters such as the owner and organization name.

### Step 2: Adding Balance to the Automation Vault

1. **Transfer Funds to the Vault:**
   - Transfer the necessary funds to the Automation Vault to cover the costs associated with task execution. This could include ETH or ERC-20 tokens, depending on the protocol requirements.

### Step 3: Approval of Callers and Relays

1. **Approval of Callers:**

   - Use functions in the Automation Vault to approve specific callers that should have permissions to interact with the Automation Vault.

2. **Approval of Relays:**
   - Ensure approval of relevant relays to be used for task execution. This might include relays such as `Keep3rRelay`, `Keep3rBondedRelay`, `GelatoRelay`, or `OpenRelay`, depending on the protocol's needs.

### Step 4: Configuration of jobs and selectors

1. **Approval of jobs:**

   - To enable task executions, you need to approve specific jobs that the Automation Vault will interact with and will be allowed.

   - Additionally, you need to approve specific function selectors for each approved job. This ensures that only designated functions within the approved jobs can be executed.

2. **Approval of selectors:**

### Step 5: Tracking and Monitoring

2. **Tracking and Monitoring:**
   - Monitor task executions through emitted events and other relevant metrics.

With these steps, you should have a solid guide for a protocol to deploy its Automation Vault, configure necessary permissions and relays, add balance, and execute automated tasks.
