<template>
  <div class="network-cards-panel">
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
          <tr v-for="row in gridData" :key="row.physicalDev">
            <td>{{ row.name }}</td>
            <td>
              <select v-model="row.deviceName">
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
  export default {
    name: 'NetworkCardsPanel',
    data() {
      return {
        gridData: [
          {
            name: 'eth0',
            deviceName: 'eth0',
            connected: 'CONNECTED',
            macAddress: '00:1A:2B:3C:4D:5E',
            physicalDev: 'eth0',
          },
          {
            name: 'eth1',
            deviceName: 'eth1',
            connected: 'DISCONNECTED',
            macAddress: '00:1A:2B:3C:4D:5F',
            physicalDev: 'eth1',
          },
        ], // Hardcoded grid data
        deviceStore: [{ physicalDev: 'eth0' }, { physicalDev: 'eth1' }], // Hardcoded device store
        interfacesForceContinue: false,
      }
    },
    methods: {
      statusText(row) {
        const connectedText =
          row.connected === 'CONNECTED' ? 'Connected' : row.connected === 'DISCONNECTED' ? 'Disconnected' : 'Unknown'
        return `${connectedText}`
      },

      statusIcon(status) {
        return status === 'CONNECTED' ? 'status-connected' : 'status-disconnected'
      },

      onClickInternetConnection() {
        console.log('Internet Connection button clicked')
        // Perform any static action or navigation if required.
      },
    },
  }
</script>

<style scoped>
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
