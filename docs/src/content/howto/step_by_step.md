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

### Step 4: Configuration of Relays

1. **Configuration of Keep3r Relay:**

   - Configure the `Keep3rRelay` if chosen for use. This may involve setting fees, gas parameters, and any other specific configurations.

2. **Configuration of Keep3r Bonded Relay:**

   - Configure the `Keep3rBondedRelay` if chosen for use. Adjust bonding requirements as per the protocol's needs.

3. **Configuration of Gelato Relay:**

   - Configure the `GelatoRelay` if chosen for use. Adjust any necessary parameters for the proper execution of automated tasks.

4. **Configuration of Open Relay:**
   - Configure the `OpenRelay` if chosen for use. Adjust any necessary parameters for the proper management of tasks from bots.

### Step 5: Tracking and Monitoring

2. **Tracking and Monitoring:**
   - Monitor task executions through emitted events and other relevant metrics.

With these steps, you should have a solid guide for a protocol to deploy its Automation Vault, configure necessary permissions and relays, add balance, and execute automated tasks.
