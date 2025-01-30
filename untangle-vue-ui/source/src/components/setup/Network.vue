<template>
  <div class="network-cards-panel">
    <h2 class="font-weight-light faint-color text-h4">{{ `Identify Network Cards` }}</h2>
    <br />
    <p>This step identifies the external, internal, and other network cards.</p>

    <!-- Description -->
    <div class="description">
      <p>
        <strong>Step 1:</strong>
        <span class="step-text">Plug an active cable into one network card to determine which network card it is.</span
        ><br />
        <strong>Step 2:</strong>
        <span class="step-text">Drag and drop the network card to map it to the desired interface.</span>
        <br />
        <strong>Step 3:</strong>
        <span class="step-text">Repeat steps 1 and 2 for each network card and then click <i>Next</i>.</span>
      </p>
    </div>

    <!-- Network Cards Table -->
    <div class="network-table-container">
      <table class="network-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Device</th>
            <th>Status</th>
            <th>MAC Address</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in gridData" :key="row.deviceName">
            <td>{{ row.name }}</td>
            <td>
              <select v-model="row.deviceName">
                <option v-for="device in deviceStore" :key="device" :value="device">
                  {{ device }}
                </option>
              </select>
            </td>
            <td>
              <span :class="statusIcon(row.connected.split(' ')[0])" class="status-dot"></span>
              {{ row.connected }}
            </td>
            <td>{{ row.macAddress }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Warning Message -->
    <div v-if="gridData.length < 2" class="inline-warning">
      <span class="warning-icon"></span>
      <div>
        <p>
          Untangle must be installed "in-line" as a gateway. This usually requires at least 2 network cards (NICs), and
          fewer than 2 NICs were detected.
        </p>
        <label>
          <input v-model="interfacesForceContinue" type="checkbox" />
          <strong>Continue anyway</strong>
        </label>
      </div>
    </div>
    <div class="button-container">
      <u-btn :small="false" style="margin: 8px 0" @click="onClickServerSettings">{{ `Server Settings` }}</u-btn>
      <u-btn :small="false" style="margin: 8px 0" @click="onClickInternetConnection">{{ `Internet Connection` }}</u-btn>
    </div>
  </div>
</template>

<script>
  import { groupBy, keys } from 'lodash'
  import Util from '@/util/setupUtil'

  export default {
    name: 'NetworkCardsPanel',
    props: {
      rpc: {
        type: Object,
        required: true,
      },
    },
    data() {
      return {
        gridData: [],
        deviceStore: [],
        interfacesForceContinue: false,
      }
    },
    created() {
      this.fetchDeviceStatus()
    },
    methods: {
      async fetchDeviceStatus() {
        try {
          const rpcResponseForAdmin = Util.setRpcJsonrpc('admin') // admin/JSONRPC
          console.log('networkSetting :', window.rpc.networkManager)
          const result2 = await rpcResponseForAdmin.networkManager.getDeviceStatus()

          const networkSettings = await rpcResponseForAdmin?.networkManager?.getNetworkSettings()

          const networkByInterfaceId = groupBy(networkSettings.interfaces.list, 'physicalDev')

          console.log('networkSettingsInterfaces :', networkByInterfaceId)

          console.log('result2 :', result2)
          if (!result2 || !result2.list) {
            console.error('Error: No device status data received')
            return
          }
          // Map devices to gridData (network card table rows)cd
          this.gridData = result2.list.map(device => {
            const interfaceDevices = networkByInterfaceId[device.deviceName]
            console.log('interfaceDevices', interfaceDevices)
            const connectedStatus = device.connected ? device.connected.toLowerCase() : 'disconnected'
            const formattedDuplex = device.duplex.toLowerCase().replace('_', '-')
            return {
              name: interfaceDevices ? interfaceDevices[0].name : 'Unknown',
              deviceName: device.deviceName,
              connected: `${connectedStatus} ${device.mbit} ${formattedDuplex} ${device.vendor}`,
              macAddress: device.macAddress || 'N/A', // Default to 'N/A' if no MAC address
            }
          })
          this.deviceStore = keys(networkByInterfaceId)
        } catch (error) {
          console.log('Failed to fetch device statuc:', error)
        }
      },
      async onClickServerSettings() {
        try {
          await Promise.resolve()
          // Navigate to the setup wizard page
          this.$router.push('/setup/system/')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      async onClickInternetConnection() {
        try {
          await Promise.resolve()
          // Navigate to the setup wizard page
          this.$router.push('/setup/internet/')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },

      statusIcon(status) {
        return status === 'connected' ? 'status-connected' : 'status-disconnected'
      },

      // onClickInternetConnection() {
      //   console.log('Internet Connection button clicked')
      //   // Perform any static action or navigation if required.
      // },
    },
  }
</script>

<style scoped>
  .button-container {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 1200px;
  }
  .network-cards-panel {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: 20px;
    border: 1px solid #ccc;
    border-radius: 5px;
    background-color: #f9f9f9;
    margin: 20px;
  }

  .description {
    margin-bottom: 20px;
    text-align: left;
  }

  .step-text {
    margin-left: 20px;
    display: inline-block;
  }

  .button-container {
    display: flex;
    justify-content: flex-end;
    margin-top: 20px;
    margin-bottom: 20px;
  }

  .internet-button {
    background-color: #007bff;
    color: white;
    border: none;
    padding: 10px 15px;
    font-size: 16px;
    cursor: pointer;
    border-radius: 5px;
    display: flex;
    align-items: center;
  }

  .internet-button .arrow {
    margin-left: 8px;
    font-size: 18px;
  }

  .internet-button:hover {
    background-color: #0056b3;
  }

  .network-table-container {
    flex-grow: 1;
    overflow-y: auto;
    margin-top: 20px;
  }

  .network-table {
    border-collapse: collapse;
    width: 100%;
  }

  .network-table th,
  .network-table td {
    border: 1px solid #ddd;
    text-align: left;
    padding: 8px;
  }

  .network-table th {
    background-color: #f4f4f4;
  }

  .network-table tr:nth-child(even) {
    background-color: #f9f9f9;
  }

  .inline-warning {
    display: flex;
    align-items: flex-start;
    margin-top: 10px;
  }

  .status-dot {
    display: inline-block;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    margin-right: 8px;
  }

  .status-connected {
    background-color: green;
  }

  .status-disconnected {
    background-color: gray;
  }

  .warning-icon {
    display: inline-block;
    width: 12px;
    height: 12px;
    background-color: orange;
    border-radius: 50%;
    margin-right: 8px;
  }
</style>
