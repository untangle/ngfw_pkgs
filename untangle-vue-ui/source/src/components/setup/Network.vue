<template>
  <v-card width="1000" class="mx-auto mt-10" flat>
    <div class="parent-card">
      <h2 class="font-weight-light faint-color text-h4">{{ `Identify Network Cards` }}</h2>
      <br />
      <p class="large-font">This step identifies the external, internal, and other network cards.</p>

      <!-- Description -->
      <div class="description">
        <p class="large-font">
          <strong>Step 1:</strong>
          <span class="step-text"
            >Plug an active cable into one network card to determine which network card it is.</span
          ><br />
          <strong>Step 2:</strong>
          <span class="step-text">Drag and drop the network card to map it to the desired interface.</span>
          <br />
          <strong>Step 3:</strong>
          <span class="step-text">Repeat steps 1 and 2 for each network card and then click <i>Next</i>.</span>
        </p>
      </div>
    </div>

    <!-- Network Cards Table -->
    <div class="network-cards-panel">
      <table class="network-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Device</th>
            <th>Icon</th>
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
            </td>
            <td>
              {{ row.connected }}
            </td>
            <td>{{ row.macAddress }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Warning Message -->

    <div class="network-cards-panel">
      <b-table hover :items="gridData" :fields="tableFields" class="network-table">
        <!-- Name column -->
        <template #cell(name)="row">
          {{ row.item.name }}
        </template>
        <!-- Device Column -->
        <template #cell(deviceName)="row">
          <b-form-select v-model="row.item.deviceName">
            <b-form-select-option v-for="device in deviceStore" :key="device" :value="device">
              {{ device }}
            </b-form-select-option>
          </b-form-select>
        </template>
        <!-- Icon Column -->
        <template #cell(statusIcon)="row">
          <span :class="statusIcon(row.item.connected)" class="status-dot"></span>
        </template>
        <!-- Status Column -->
        <template #cell(connected)="row">
          {{ row.item.connected }}
        </template>
        <!-- MAC Address Column -->
        <template #cell(macAddress)="row">
          {{ row.item.macAddress }}
        </template>
      </b-table>
    </div>

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
      <u-btn :small="false" style="margin: 8px 0" @click="onClickBack">{{ `Back` }}</u-btn>
      <u-btn :small="false" style="margin: 8px 0" @click="onClickNext">{{ `Next` }}</u-btn>
    </div>
  </v-card>
</template>

<script>
  import Vue from 'vue'
  import { BTable, BFormSelect, BFormSelectOption } from 'bootstrap-vue'
  import { groupBy, keys } from 'lodash'
  // import draggable from 'vuedraggable'
  import Util from '@/util/setupUtil'
  Vue.component('BTable', BTable)
  Vue.component('BFormSelect', BFormSelect)
  Vue.component('BFormSelectOption', BFormSelectOption)

  export default {
    name: 'NetworkCardsPanel',
    // components: {
    //   draggable,
    // },
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
        tableFields: [
          { key: 'drag', label: 'Drag' },
          { key: 'name', label: 'Name' },
          { key: 'deviceName', label: 'Device' },
          { key: 'statusIcon', label: 'Icon' },
          { key: 'connected', label: 'Status' },
          { key: 'macAddress', label: 'MAC Address' },
        ],
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

          this.networkSettings = await rpcResponseForAdmin?.networkManager?.getNetworkSettings()

          const networkByInterfaceId = groupBy(this.networkSettings.interfaces.list, 'physicalDev')

          const networkByDeviceName = groupBy(result2.list, 'deviceName')

          console.log('networkSettingsDeviceName :', networkByDeviceName)
          console.log('result2 :', result2)

          if (!result2 || !result2.list) {
            console.error('Error: No device status data received')
            return
          }
          // Map devices to gridData (network card table rows)cd
          this.gridData = result2.list.map(device => {
            const interfaceDevices = networkByInterfaceId[device.deviceName]
            const connectedStatus = device.connected ? device.connected.toLowerCase() : 'disconnected'
            const formattedDuplex = device.duplex.toLowerCase().replace('_', '-')
            return {
              name: interfaceDevices ? interfaceDevices[0].name : 'Unknown',
              deviceName: device.deviceName,
              connected: `${connectedStatus} ${device.mbit} ${formattedDuplex} ${device.vendor}`,
              macAddress: device.macAddress || 'N/A', // Default to 'N/A' if no MAC address
            }
          })
          this.deviceStore = keys(networkByDeviceName)
        } catch (error) {
          console.log('Failed to fetch device statuc:', error)
        }
      },
      async onClickBack() {
        try {
          await Promise.resolve()
          // Navigate to the setup wizard page
          this.$router.push('/setup/system/')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      async onClickNext() {
        try {
          // const rpcResponseForAdmin = Util.setRpcJsonrpc('admin')
          // // console.log(window.rpc.setup)
          // if (this.timezoneID !== this.timezone) {
          //   console.log('timeZone', this.timezone)
          //   const timezoneId = this.timezone.split(' ')[1]
          //   await window.rpc.setup.setTimeZone(timezoneId)
          //   console.log('rpcResponseForAdmin responce:', rpcResponseForAdmin)
          // }
          // // alert('Settings saved successfully.')
          // // if no changes/remapping skip this step
          // const interfacesMap = {}

          // this.gridData.each(function (currentRow) {
          //   interfacesMap[currentRow.name] = currentRow.deviceName
          // })

          // // apply new physicalDev for each interface from initial Network Settings
          // this.networkSettings.interfaces.list.each(function (intf) {
          //   if (!intf.isVlanInterface) {
          //     intf.physicalDev = interfacesMap[intf.name]
          //   }
          // })

          // rpcResponseForAdmin.networkManager.setNetworkSettings(this.networkSettings)
          // Navigate to the setup wizard page
          await Promise.resolve()

          this.$router.push('/setup/internet/')
        } catch (error) {
          console.error('Error saving settings:', error)
          alert('Failed to save settings. Please try again.')
        }
      },

      statusIcon(status) {
        return status.includes('connected') ? 'status-connected' : 'status-disconnected'
      },

      // onClickInternetConnection() {
      //   console.log('Internet Connection button clicked')
      //   // Perform any static action or navigation if required.
      // },
      // onBeforeDrop: Method to swap columns when dragging
    },
  }
</script>

<style scoped>
  .large-font {
    font-size: 20px; /* Adjust this value as needed */
  }
  .network-cards-panel {
    display: flex;
    width: 96%;
    padding: 20px;
    border: 2px solid #ccc;
    border-radius: -5px;
    background-color: #f9f9f9;
    margin: 20px;
  }
  .parent-card {
    display: flex;
    flex-direction: column;
    height: 100%;
    border-radius: 5px;
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
    margin-right: 18px;
    margin-left: 600px;
    gap: 720px;
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
    box-sizing: border-box;
  }
  .network-table select {
    font-size: 16px; /* Increase the font size of the dropdown text */
    padding-left: 6px; /* Increase padding inside the select element */
    padding-right: 10px;
    height: 60px; /* Increase the height of the select box */
    width: 100%; /* Optional: Ensures the select spans the full width of its container */
    box-sizing: border-box; /* Ensures padding is included in the width */
  }

  .network-table select option {
    font-size: 16px; /* Increase the font size of the options inside the dropdown */
    padding: 10px; /* Increase padding for better readability */
  }

  .network-table th,
  .network-table td {
    border: 1px solid #b64a4a;
    text-align: right;
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
    align-items: center;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    margin-right: 6px;
    margin-left: 18px;
    justify-content: center;
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
