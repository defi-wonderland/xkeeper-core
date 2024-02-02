## Tutorial: Automate with Gelato Relay

This guide provides a step-by-step process to create and manage automated tasks using the Gelato Network.

### Step 1: Deployment of the Automation Vault

**Automation Vault**

    - If you already have an automation vault, you can skip this step, if not, deploy and configure the automation vault. You can follow the guide in step by step (./step_by_step.md).

### Step 2: Create a task in Gelato

**Create Task**

    - Create a task in gelato is needed. You can do it using the UI provided by Gelato. **https://app.gelato.network/functions**.

    - Inside configure the trigger option you want for the execution of your job.

    - First you will have to configure the solidity function. This will have to contain a checker function that applies the desired logic and passes as a parameter the payload needed to execute your job. In **https://github.com/defi-wonderland/xkeeper-core**, you have the BasicJob contract to obtain an example of how to send the necessary data.

    - Finally, we will select the destination contract, in this case it will be the `Gelato Relay`.

### Step 3: Tracking and Monitoring

**Tracking and Monitoring:**

    - Once the task is created, you will have information about the executions and logs.
