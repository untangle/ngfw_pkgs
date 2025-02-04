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
    <!-- Warning Message -->

    <div fixed responsive class="network-cards-panel">
      <b-table
        hover
        :items="gridData"
        :fields="tableFields"
        thead-class="text-left"
        class="network-table"
        :bordered="true"
        :striped="false"
        :small="false"
      >
        <!-- Drag Icon Column -->
        <template #cell(drag)="row">
          <span
            class="drag-handle"
            style="cursor: move"
            draggable="true"
            @dragstart="dragStart($event, row.item)"
            @dragover="dragOver($event)"
            @drop="drop($event, row.item)"
            @dragend="dragEnd"
            >&#x2630;</span
          >
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
    draggingRow: null,
    dragStartIndex: null,
    dragEndIndex: null,
    props: {
      rpc: {
        type: Object,
        required: true,
      },
    },
    data() {
      return {
        gridData: [],
        tempArray: [],
        deviceStore: [],
        intfOrderArr: [],
        draggingItem: null,
        intfListLength: 0,
        networkSettings: null,
        enableAutoRefresh: true,
        interfacesForceContinue: false,
        bordered: true,
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
      this.enableAutoRefresh = true
      setTimeout(this.autoRefreshInterfaces, 3000)
    },

    destroyed() {
      this.enableAutoRefresh = false
    },
    methods: {
      dragStart(event, item) {
        this.tempArray = this.gridData.map(item => ({ ...item }))
        this.draggingItem = item
        if (event && event.dataTransfer) {
          const itemString = JSON.stringify(item)
          event.dataTransfer.setData('text/plain', itemString)
        }
      },
      dragOver(event) {
        event.preventDefault()
      },
      drop(event, targetItem) {
        event.preventDefault()
        const draggedItemData = event.dataTransfer.getData('text/plain')
        if (draggedItemData) {
          const draggedItem = JSON.parse(draggedItemData)
          this.onBeforeDrop(draggedItem, targetItem)
        }
      },
      dragEnd() {
        this.draggingItem = null
      },

      onBeforeDrop(sourceRecord, targetRecord) {
        const sourceRecordCopy = { ...sourceRecord } // shallow copy
        const targetRecordCopy = { ...targetRecord }

        // make sure sourceRecord & targetRecord are defined
        if (sourceRecord === null || targetRecord === null) {
          return
        }

        sourceRecord.deviceName = targetRecordCopy.deviceName
        sourceRecord.physicalDev = targetRecordCopy.physicalDev
        // sourceRecord.systemDev =  targetRecordCopy.systemDev
        // sourceRecord.symbolicDev = targetRecordCopy.symbolicDev
        sourceRecord.macAddress = targetRecordCopy.macAddress
        sourceRecord.duplex = targetRecordCopy.duplex
        sourceRecord.vendor = targetRecordCopy.vendor
        sourceRecord.mbit = targetRecordCopy.mbit
        sourceRecord.connected = targetRecordCopy.connected

        targetRecord.deviceName = sourceRecordCopy.deviceName
        targetRecord.physicalDev = sourceRecordCopy.physicalDev
        // targetRecord.systemDev = sourceRecordCopy.systemDev
        // targetRecord.symbolicDev = sourceRecordCopy.symbolicDev
        targetRecord.macAddress = sourceRecordCopy.macAddress
        targetRecord.duplex = sourceRecordCopy.duplex
        targetRecord.vendor = sourceRecordCopy.vendor
        targetRecord.mbit = sourceRecordCopy.mbit
        targetRecord.connected = sourceRecordCopy.connected

        const sourceIndex = this.tempArray.findIndex(record => record.physicalDev === sourceRecord.physicalDev)
        const targetIndex = this.tempArray.findIndex(record => record.physicalDev === targetRecord.physicalDev)

        if (sourceIndex !== -1 && targetIndex !== -1) {
          const temp = this.tempArray[sourceIndex]
          this.tempArray[sourceIndex] = this.tempArray[targetIndex]
          this.tempArray[targetIndex] = temp
        }

        this.tempArray.forEach((item, index) => {
          if (this.gridData[index]) {
            this.$set(this.gridData, index, { ...item })
          }
        })
      },
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

          forEach(interfaces, intf => {
            if (deviceStatusMap[intf.physicalDev]) {
              Object.keys(deviceStatusMap[intf.physicalDev]).forEach(key => {
                if (!Object.prototype.hasOwnProperty.call(intf, key)) {
                  this.$set(intf, key, deviceStatusMap[intf.physicalDev][key])
                }
              })
            }
          })
          this.gridData = interfaces
          forEach(interfaces, function (intf) {
            physicalDevsStore.push({ 'physicalDev': intf.physicalDev })
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
        if (!this.enableAutoRefresh) {
          return
        }
        try {
          const rpc = Util.setRpcJsonrpc('admin') // admin/JSONRPC
          const networkSettings = await rpc?.networkManager?.getNetworkSettings()
          const interfaces = []

          this.intfListLength = networkSettings.interfaces.list.length
          networkSettings.interfaces.list.forEach(function (intf) {
            if (!intf.isVlanInterface) {
              interfaces.push(intf)
            }
          })

          if (interfaces.length !== this.gridData.length) {
            alert('There are new interfaces, please restart the wizard.')
          }

          const deviceStatusResult = await rpc.networkManager.getDeviceStatus()

          const deviceStatusMap = deviceStatusResult.list.reduce((map, item) => {
            map[item.deviceName] = item
            return map
          }, {})

          this.gridData.forEach(function (row) {
            const deviceStatus = deviceStatusMap[row.physicalDev]
            if (deviceStatus !== null) {
              row.connected = deviceStatus.connected
            }
          })
          if (this.enableAutoRefresh) {
            setTimeout(this.autoRefreshInterfaces, 3000)
          }
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
          const interfacesMap = {}

          // TODO: how to check the row modification
          // if (grid.getStore().getModifiedRecords().length === 0) { cb(); return; }

          console.log('Get Settings : ', this.gridData)
          this.gridData.forEach(function (currentRow) {
            interfacesMap[currentRow.interfaceId] = currentRow.physicalDev
          })

          // apply new physicalDev for each interface from initial Network Settings
          this.networkSettings.interfaces.list.forEach(function (intf) {
            if (!intf.isVlanInterface) {
              intf.physicalDev = interfacesMap[intf.interfaceId]
            }
          })

          console.log('Network Settings :', this.networkSettings)

          await window.rpc.networkManager.setNetworkSettings(this.networkSettings)
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
    },
  }
</script>

<style scoped>
  .large-font {
    font-size: 17px;
  }
  .network-cards-panel {
    display: flex;
    width: 90%;
    padding: 20px;
    border: 2px solid #ccc;
    border-radius: 5px;
    background-color: #ebe9e9;
    margin: 10px;
    overflow: auto;
  }
  .network-table {
    width: 100%;
    max-height: 500px;
    border-collapse: collapse;
    box-sizing: border-box;
  }
  .network-table td,
  .network-table th {
    border: 1px solid #ccc;
    padding: 10px;
    text-align: left;
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
    margin-right: 90px;
    margin-left: 600px;
    gap: 660px;
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
  .dragging {
    opacity: 0.5;
    background-color: #f1f1f1;
  }
  .internet-button .arrow {
    margin-left: 8px;
    font-size: 18px;
  }
  .internet-button:hover {
    background-color: #0056b3;
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
    align-items: left;
    background-color: green;
  }
  .status-disconnected {
    align-items: left;
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
  .draggable-row {
    cursor: move;
  }
  .ghost {
    opacity: 0.4;
  }
  .drag-handle {
    cursor: move;
    font-size: 1.5em;
    color: gray;
  }
</style>
