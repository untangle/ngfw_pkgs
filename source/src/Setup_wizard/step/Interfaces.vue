<template>
  <InternetConnection v-if="showInternetConnection" :setup-rpc="setupRpc" :admin-rpc="adminRpc" />
  <div v-else class="network-cards-panel">
    <h1>Network Cards</h1>
    <p>Identify Network Cards</p>

    <!-- Description -->
    <div class="description">
      <p>
        <strong>Step 1:</strong>
        <span class="step-text">Plug an active cable into one network card to determine which network card it is.</span
        ><br />
        <strong>Step 2:</strong>
        <span class="step-text">Drag and drop the network card to map it to the desired interface.</span><br />
        <strong>Step 3:</strong>
        <span class="step-text">Repeat steps 1 and 2 for each network card and then click <i>Next</i>.</span>
      </p>
    </div>

    <!-- Network Cards Table -->
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
        <tr v-for="row in gridData" :key="row.physicalDev">
          <td>{{ row.name }}</td>
          <td>
            <select v-model="row.deviceName" @change="setInterfacesMap(row)">
              <option v-for="device in deviceStore" :key="device.physicalDev" :value="device.physicalDev">
                {{ device.physicalDev }}
              </option>
            </select>
          </td>
          <td>
            <span :class="statusIcon(row.connected)" class="status-dot"></span>
            {{ statusText(row) }}
          </td>
          <td>{{ row.macAddress }}</td>
        </tr>
      </tbody>
    </table>

    <!-- Internet Connection Button -->
    <div class="button-container">
      <button class="internet-button" @click="onClickInternetConnection">
        Internet Connection <span class="arrow">→</span>
      </button>
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
  </div>
</template>

<script>
  import InternetConnection from '@/Setup_wizard/step/InternetConnection.vue'

  export default {
    name: 'NetworkCardsPanel',
    components: {
      InternetConnection,
    },
    props: {
      setupRpc: {
        type: Object,
        required: true,
      },
      adminRpc: {
        type: Object,
        required: true,
      },
    },
    data() {
      return {
        gridData: [], // The data to display in the grid
        deviceStore: [], // List of available devices for dropdown
        interfacesForceContinue: false, // Checkbox state
        autoRefreshEnabled: false, // Auto-refresh flag
        showInternetConnection: false,
      }
    },
    mounted() {
      this.fetchInterfaces()
    },
    beforeDestroy() {
      this.stopAutoRefresh()
    },
    methods: {
      // Fetch initial interface and device data
      fetchInterfaces() {
        console.log('Fetching interfaces...')

        this.adminRpc.networkManager().getNetworkSettings((result, ex) => {
          if (ex) {
            console.error('Unable to load interfaces:', ex)
            return
          }

          console.log('Interfaces Result:', result)

          const interfaces = []
          const devices = []

          result.interfaces.list.forEach(intf => {
            if (!intf.isVlanInterface) {
              interfaces.push(intf)
              devices.push({ physicalDev: intf.physicalDev })
            }
          })

          console.log('Filtered Interfaces:', interfaces)
          console.log('Devices:', devices)

          this.adminRpc.networkManager().getDeviceStatus((result2, ex2) => {
            if (ex2) {
              console.error('Error fetching device status:', ex2)
              return
            }

            const deviceStatusMap = result2.list.reduce((map, device) => {
              map[device.deviceName] = device
              return map
            }, {})

            interfaces.forEach(intf => {
              Object.assign(intf, deviceStatusMap[intf.physicalDev] || {})
            })

            this.gridData = interfaces.map(intf => ({
              name: intf.name || 'Unknown',
              deviceName: intf.physicalDev,
              connected: intf.connected || 'DISCONNECTED',
              macAddress: intf.macAddress || 'N/A',
              duplex: intf.duplex || 'UNKNOWN',
              vendor: intf.vendor || 'Unknown Vendor',
              mbit: intf.mbit || 0,
              physicalDev: intf.physicalDev,
            }))

            this.deviceStore = devices
            console.log('Device Store:', this.deviceStore)
            console.log('Grid Data:', this.gridData)
          })
        })
      },

      // Map interfaces when a device is selected or rows are reordered
      setInterfacesMap(row) {
        console.log('Selected Interface:', row)
      },

      // Handle row drop event for drag-and-drop
      onRowDrop(draggedRow, droppedRow) {
        console.log('Row dropped:', draggedRow, droppedRow)
      },

      // Get the status text based on connection status
      statusText(row) {
        const connectedText =
          row.connected === 'CONNECTED' ? 'Connected' : row.connected === 'DISCONNECTED' ? 'Disconnected' : 'Unknown'
        return `${connectedText} ${
          row.duplex === 'FULL_DUPLEX' ? 'Full Duplex' : row.duplex === 'HALF_DUPLEX' ? 'Half Duplex' : 'Unknown Duplex'
        } ${row.mbit || ''}`
      },

      // Get the corresponding status icon
      statusIcon(status) {
        return status === 'CONNECTED' ? 'status-connected' : 'status-disconnected'
      },

      // Start auto-refresh to periodically update data
      startAutoRefresh() {
        this.autoRefreshEnabled = true
        this.refreshInterfaces()
      },

      // Stop auto-refresh
      stopAutoRefresh() {
        this.autoRefreshEnabled = false
      },

      // Refresh the interface data periodically
      refreshInterfaces() {
        if (!this.autoRefreshEnabled) return
        this.fetchInterfaces()
        setTimeout(this.refreshInterfaces, 3000) // Refresh every 3 seconds
      },

      onClickInternetConnection() {
        this.showInternetConnection = true
      },
    },
  }
</script>

<style scoped>
  .network-cards-panel {
    padding: 20px;
    border: 1px solid #ccc;
    border-radius: 5px;
    background-color: #f9f9f9;
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
  .network-table {
    border-collapse: collapse;
    width: 100%;
    margin-top: 20px;
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
