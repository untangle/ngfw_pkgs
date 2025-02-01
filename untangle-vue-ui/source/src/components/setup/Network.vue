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
    <!-- <div class="network-cards-panel">
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
    </div> -->

    <!-- Warning Message -->

    <div class="network-cards-panel">
      <draggable
        v-model="gridData"
        :group="{ name: 'network-rows', pull: 'clone' }"
        class="network-table"
        handle=".drag-handle"
        :animation="300"
        @start="onDragStart"
        @end="onDragEnd"
        @drag="onDrag"
        @drop="onDrop"
      >
        <b-table hover :items="gridData" :fields="tableFields" class="network-table">
          <!-- Drag Icon Column -->
          <template #cell(drag)>
            <span class="drag-handle" style="cursor: move">&#x2630;</span>
            <!-- You can change this to an icon -->
          </template>
          <!-- Name column -->
          <template #cell(name)="row">
            {{ row.item.name }}
          </template>
          <!-- Device Column -->
          <template #cell(deviceName)="row">
            <b-form-select v-model="row.item.physicalDev" @change="setInterfacesMap(row.item)">
              <b-form-select-option v-for="device in deviceStore" :key="device.physicalDev" :value="device.physicalDev">
                {{ device.physicalDev }}
              </b-form-select-option>
            </b-form-select>
          </template>
          <!-- Icon Column -->
          <template #cell(statusIcon)="row">
            <span :class="statusIcon(row.item.connected)" class="status-dot"></span>
          </template>
          <!-- Status Column -->
          <template #cell(connected)="row">
            {{ getConnectedStr(row.item) }}
          </template>
          <!-- MAC Address Column -->
          <template #cell(macAddress)="row">
            {{ row.item.macAddress }}
          </template>
        </b-table>
      </draggable>
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
  import { forEach } from 'lodash'
  import VueDraggable from 'vuedraggable'
  import Util from '@/util/setupUtil'
  Vue.use(VueDraggable)

  Vue.component('BTable', BTable)
  Vue.component('BFormSelect', BFormSelect)
  Vue.component('BFormSelectOption', BFormSelectOption)

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
        intfOrderArr: [],
        intfListLength: 0,
        networkSettings: null,
        enableAutoRefresh: true,
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
      this.getSettings()
      this.autoRefreshInterfaces()
    },
    methods: {
      // Event handler for when drag starts
      onDragStart(event) {
        console.log('Drag Started', event)
        // You can perform additional actions here, like changing styles or preparing data
      },

      // Event handler for when drag ends
      onDragEnd(event) {
        console.log('Drag Ended', event)
        // Reset styles or handle any cleanup after drag
      },

      // Event handler for during drag (as the row is being dragged)
      onDrag(event) {
        console.log('Dragging...', event)
        // You can update state or track drag movements
      },

      // Event handler for when an item is dropped
      onDrop(event) {
        console.log('Item Dropped', event)
        // Handle the drop logic (e.g., saving changes, updating order)
      },

      // onBeforeDrop(node, data, overModel, dropPosition, dropHandlers) {
      //   dropHandlers.wait = true

      //   const sourceRecord = data.records[0]
      //   const targetRecord = overModel

      //   if (sourceRecord === null || targetRecord === null) {
      //     dropHandlers.cancelDrop()
      //     return
      //   }

      //   // clone phantom records to manipulate (switch) data properly
      //   const sourceRecordCopy = { ...sourceRecord } // Shallow copy
      //   const targetRecordCopy = { ...targetRecord }
      //   sourceRecord.deviceName = targetRecordCopy.deviceName
      //   sourceRecord.physicalDev = targetRecordCopy.physicalDev
      //   // sourceRecord.systemDev:   targetRecordCopy.systemDev
      //   // sourceRecord.symbolicDev: targetRecordCopy.symbolicDev
      //   sourceRecord.macAddress = targetRecordCopy.macAddress
      //   sourceRecord.duplex = targetRecordCopy.duplex
      //   sourceRecord.vendor = targetRecordCopy.vendor
      //   sourceRecord.mbit = targetRecordCopy.mbit
      //   sourceRecord.connected = targetRecordCopy.connected
      //   targetRecord.deviceName = sourceRecordCopy.deviceName
      //   targetRecord.physicalDev = sourceRecordCopy.physicalDev
      //   // targetRecord.systemDev = sourceRecordCopy.systemDev
      //   // targetRecord.symbolicDev = sourceRecordCopy.symbolicDev
      //   targetRecord.macAddress = sourceRecordCopy.macAddress
      //   targetRecord.duplex = sourceRecordCopy.duplex
      //   targetRecord.vendor = sourceRecordCopy.vendor
      //   targetRecord.mbit = sourceRecordCopy.mbit
      //   targetRecord.connected = sourceRecordCopy.connected
      //   dropHandlers.cancelDrop() // cancel drop as we do not want to reorder rows but just to set physicalDev
      // },

      getConnectedStr(deviceStatus) {
        const connected = deviceStatus.connected
        const mbit = deviceStatus.mbit
        const duplex = deviceStatus.duplex
        const vendor = deviceStatus.vendor
        const connectedStr =
          connected === 'CONNECTED' ? 'connected' : connected === 'DISCONNECTED' ? 'disconnected' : 'unknown'
        const duplexStr =
          duplex === 'FULL_DUPLEX' ? 'full-duplex' : duplex === 'HALF_DUPLEX' ? 'half-duplex' : 'unknown'
        return connectedStr + ' ' + mbit + ' ' + duplexStr + ' ' + vendor
      },
      async getSettings() {
        try {
          const rpc = Util.setRpcJsonrpc('admin')
          this.networkSettings = await rpc?.networkManager?.getNetworkSettings()

          const physicalDevsStore = []
          this.intfOrderArr = []

          this.intfListLength = this.networkSettings.interfaces.list.length

          const interfaces = []
          const devices = []

          forEach(this.networkSettings.interfaces.list, function (intf) {
            if (!intf.isVlanInterface) {
              interfaces.push(intf)
              devices.push({ physicalDev: intf.physicalDev })
            }
          })

          const deviceRecords = await rpc.networkManager.getDeviceStatus()

          const deviceStatusMap = deviceRecords.list.reduce((map, item) => {
            map[item.deviceName] = item
            return map
          }, {})

          // console.log('deviceStatusMap :', deviceStatusMap)
          forEach(interfaces, intf => {
            // Check if the physicalDev exists in deviceStatusMap and merge the fields directly into the intf object
            if (deviceStatusMap[intf.physicalDev]) {
              Object.keys(deviceStatusMap[intf.physicalDev]).forEach(key => {
                if (!Object.prototype.hasOwnProperty.call(intf, key)) {
                  this.$set(intf, key, deviceStatusMap[intf.physicalDev][key])
                }
              })
            }
          })

          // TODO: check whether this is required for grid
          // store data is not binded, so grid changes are not affecting the network settings
          // grid.getStore().loadData(Ext.clone(interfaces));
          // grid.getStore().commitChanges(); // so the grid is not dirty after initial data load

          this.gridData = interfaces
          console.log('physicalDevsStore: ', physicalDevsStore)

          forEach(interfaces, function (intf) {
            physicalDevsStore.push({ 'physicalDev': intf.physicalDev })
            // me.intfOrderArr.push(Ext.clone(intf));
          })
          this.deviceStore = physicalDevsStore

          // update the steps based on interfaces
          // me.getView().up('setupwizard').fireEvent('syncsteps');
        } catch (error) {
          console.log('Failed to fetch device settings:', error)
        }
      },
      // used when mapping from comboboxes
      setInterfacesMap(row) {
        const oldValue = row.deviceName
        const newValue = row.physicalDev

        // Find the source and target records in gridData
        const sourceRecord = this.gridData.find(currentRow => currentRow.deviceName === oldValue)
        const targetRecord = this.gridData.find(currentRow => currentRow.deviceName === newValue)

        // make sure sourceRecord & targetRecord are defined
        if (!sourceRecord || !targetRecord || sourceRecord.name === targetRecord.name) {
          return
        }

        // Clone the source and target records to avoid direct mutation
        const sourceRecordCopy = { ...sourceRecord }
        const targetRecordCopy = { ...targetRecord }

        // switch data between records (interfaces) - remapping
        sourceRecord.deviceName = newValue
        sourceRecord.physicalDev = newValue
        sourceRecord.macAddress = targetRecordCopy.macAddress
        sourceRecord.duplex = targetRecordCopy.duplex
        sourceRecord.vendor = targetRecordCopy.vendor
        sourceRecord.mbit = targetRecordCopy.mbit
        sourceRecord.connected = targetRecordCopy.connected

        targetRecord.deviceName = oldValue
        targetRecord.physicalDev = oldValue
        targetRecord.macAddress = sourceRecordCopy.macAddress
        targetRecord.duplex = sourceRecordCopy.duplex
        targetRecord.vendor = sourceRecordCopy.vendor
        targetRecord.mbit = sourceRecordCopy.mbit
        targetRecord.connected = sourceRecordCopy.connected
      },
      async autoRefreshInterfaces() {
        // TODO
        // if (!me.enableAutoRefresh) { return; }
        try {
          const rpc = Util.setRpcJsonrpc('admin') // admin/JSONRPC

          const networkSettings = await rpc?.networkManager?.getNetworkSettings()

          // if (ex) {
          //   Util.handleException('Unable to refresh the interfaces.'.t())
          //   return
          // }
          const interfaces = []

          this.intfListLength = networkSettings.interfaces.list.length

          networkSettings.interfaces.list.forEach(function (intf) {
            if (!intf.isVlanInterface) {
              interfaces.push(intf)
            }
          })

          this.gridData = interfaces
          console.log('grid data list :', this.gridData)

          if (interfaces.length !== this.gridData.length) {
            // TODO
            // Ext.MessageBox.alert('New interfaces'.t(), 'There are new interfaces, please restart the wizard.', '');
          }

          const deviceStatusResult = await rpc.networkManager.getDeviceStatus()
          const deviceStatusMap = deviceStatusResult.list.reduce((map, item) => {
            map[item.deviceName] = item
            return map
          }, {})

          console.log('Grid data:', this.gridData)
          this.gridData.forEach(function (row) {
            const deviceStatus = deviceStatusMap[row.physicalDev]
            if (deviceStatus !== null) {
              row.connected = deviceStatus.connected
            }
          })
          // TODO
          // if (me.enableAutoRefresh) {
          //     Ext.defer(me.autoRefreshInterfaces, 3000, me);
          // }
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
          const rpcResponseForAdmin = Util.setRpcJsonrpc('admin')
          console.log('rpcResponseForAdmin responce:', rpcResponseForAdmin)

          const interfacesMap = {}

          // TODO: how to check the row modification
          // if (grid.getStore().getModifiedRecords().length === 0) { cb(); return; }

          // apply new physicalDev for each interface from initial Network Settings
          this.gridData.forEach(function (currentRow) {
            interfacesMap[currentRow.interfaceId] = currentRow.physicalDev
          })

          // apply new physicalDev for each interface from initial Network Settings
          this.networkSettings.interfaces.list.forEach(function (intf) {
            if (!intf.isVlanInterface) {
              intf.physicalDev = interfacesMap[intf.interfaceId]
            }
          })

          console.log('networkSettings :++', this.networkSettings)
          rpcResponseForAdmin.networkManager.setNetworkSettings(this.networkSettings)
          // Navigate to the setup wizard page
          await Promise.resolve()

          this.$router.push('/setup/internet/')
        } catch (error) {
          console.error('Error saving settings:', error)
          alert('Failed to save settings. Please try again.')
        }
      },

      statusIcon(status) {
        return status === 'CONNECTED' ? 'status-connected' : 'status-disconnected'
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
  /* Drag handle styling */
  .drag-handle {
    cursor: move;
    font-size: 1.5em;
    color: gray;
  }
</style>
