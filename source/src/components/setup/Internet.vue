<template>
  <div class="setup-wizard">
    <h3 class="title">Configure the Internet Connection</h3>
    <p class="error-message">No Internet Connection! Click on 'Test Connectivity' to verify.</p>

    <div v-if="wan">
      <!-- Configuration Type Radio Buttons in Single Line -->
      <div class="config-type">
        <label class="config-label">Configuration Type</label>
        <div class="radio-group">
          <label> <input v-model="wan.v4ConfigType" type="radio" value="AUTO" /> Auto (DHCP) </label>
          <label> <input v-model="wan.v4ConfigType" type="radio" value="STATIC" /> Static </label>
          <label> <input v-model="wan.v4ConfigType" type="radio" value="PPPOE" /> PPPoE </label>
        </div>
      </div>

      <!-- Static Configuration Fields -->
      <div v-if="wan.v4ConfigType === 'STATIC'" class="static-config">
        <label>IP Address</label>
        <input v-model="wan.v4StaticAddress" type="text" />

        <label>Netmask</label>
        <select v-model="wan.v4StaticPrefix">
          <option v-for="(prefix, index) in netmaskList" :key="index" :value="prefix">{{ prefix }}</option>
        </select>

        <label>Gateway</label>
        <input v-model="wan.v4StaticGateway" type="text" />

        <label>Primary DNS</label>
        <input v-model="wan.v4StaticDns1" type="text" />

        <label>Secondary DNS</label>
        <input v-model="wan.v4StaticDns2" type="text" />
      </div>

      <!-- Auto (DHCP) Configuration Fields -->
      <div v-if="wan.v4ConfigType === 'AUTO'" class="auto-config">
        <div class="status-grid">
          <div class="status-item">
            <label>IP Address:</label>
            <span>{{ wan.v4AutoIpAddress }}</span>
          </div>
          <div class="status-item">
            <label>Netmask:</label>
            <span>{{ wan.v4AutoNetmask }}</span>
          </div>
          <div class="status-item">
            <label>Gateway:</label>
            <span>{{ wan.v4AutoGateway }}</span>
          </div>
          <div class="status-item">
            <label>Primary DNS:</label>
            <span>{{ wan.v4AutoDns1 }}</span>
          </div>
          <div class="status-item">
            <label>Secondary DNS:</label>
            <span>{{ wan.v4AutoDns2 }}</span>
          </div>
        </div>
        <button class="renew-button" @click="renewDHCP">Renew DHCP</button>
      </div>

      <!-- PPPoE Configuration Fields -->
      <div v-if="wan.v4ConfigType === 'PPPOE'" class="pppoe-config">
        <label>Username</label>
        <input v-model="wan.v4PPPoEUsername" type="text" />

        <label>Password</label>
        <input v-model="wan.v4PPPoEPassword" type="password" />
      </div>

      <button class="test-button" @click="testConnectivity">Test Connectivity</button>
    </div>
  </div>
</template>

<script>
  export default {
    name: 'Internet',
    data() {
      return {
        isRemoteReachable: null,
        wan: {
          v4ConfigType: 'AUTO',
          v4StaticAddress: '',
          v4StaticPrefix: 24,
          v4StaticGateway: '',
          v4StaticDns1: '',
          v4StaticDns2: '',
          v4PPPoEUsername: '',
          v4PPPoEPassword: '',
          // Fields for Auto (DHCP) Configuration
          v4AutoIpAddress: '10.0.2.15',
          v4AutoNetmask: '/24 - 255.255.255.0',
          v4AutoGateway: '10.0.2.2',
          v4AutoDns1: '10.14.0.1',
          v4AutoDns2: '8.8.8.8',
        },
        netmaskList: ['8', '16', '24', '32'], // Example netmask options
      }
    },
    mounted() {
      this.checkRemoteReachability()
      this.getSettings()
    },
    methods: {
      checkRemoteReachability() {
        // Simulate the check for remote reachability
        this.isRemoteReachable = true // Example value
      },
      getSettings() {
        // Simulate getting WAN settings
        this.wan = {
          v4ConfigType: 'STATIC',
          v4StaticAddress: '192.168.1.1',
          v4StaticPrefix: 24,
          v4StaticGateway: '192.168.1.254',
          v4StaticDns1: '8.8.8.8',
          v4StaticDns2: '8.8.4.4',
          v4AutoIpAddress: '10.0.2.15',
          v4AutoNetmask: '/24 - 255.255.255.0',
          v4AutoGateway: '10.0.2.2',
          v4AutoDns1: '10.14.0.1',
          v4AutoDns2: '8.8.8.8',
        }
      },
      testConnectivity() {
        // Simulate testing internet connectivity
        alert('Testing Connectivity...')
      },
      renewDHCP() {
        // Simulate renewing DHCP lease
        alert('Renewing DHCP...')
      },
    },
  }
</script>

<style scoped>
  .setup-wizard {
    max-width: 800px;
    margin: 0 auto;
    font-family: Arial, sans-serif;
    padding: 20px;
  }

  .title {
    font-size: 24px;
    font-weight: bold;
    margin-bottom: 20px;
    text-align: center;
  }

  .error-message {
    color: red;
    text-align: center;
    font-size: 16px;
  }

  .config-type {
    margin-bottom: 20px;
  }

  .config-label {
    font-size: 16px;
    font-weight: bold;
  }

  .radio-group {
    display: flex;
    justify-content: flex-start;
  }

  .radio-group label {
    margin-right: 20px;
    font-size: 14px;
  }

  .static-config,
  .auto-config,
  .pppoe-config {
    margin-top: 20px;
  }

  label {
    font-size: 14px;
    font-weight: normal;
    display: block;
    margin-top: 10px;
  }

  input[type='text'],
  input[type='password'],
  select {
    width: 100%;
    padding: 8px;
    margin-top: 5px;
    border: 1px solid #ccc;
    border-radius: 4px;
  }

  button.test-button {
    margin-top: 20px;
    padding: 10px 20px;
    background-color: #42b983;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
  }

  button.test-button:hover {
    background-color: #35495e;
  }

  button.renew-button {
    margin-top: 20px;
    padding: 10px 20px;
    background-color: #42b983;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
  }

  button.renew-button:hover {
    background-color: #35495e;
  }

  .status-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }

  .status-item {
    font-size: 14px;
  }

  .status-item label {
    font-weight: bold;
  }

  .status-item span {
    font-weight: normal;
  }
</style>
