<template>
  <v-card width="1100" class="mx-auto mt-4" flat>
    <SetupLayout />
    <v-container class="main-div">
      <div class="parent-card">
        <h2 class="font-weight-light faint-color text-h4">{{ `Identify Network Cards` }}</h2>
        <br />
        <p class="large-font">This step identifies the external, internal, and other network cards.</p>

        <!-- Description -->
        <div class="description">
          <p class="large-font">
            <strong>Step 1:</strong>
            <span class="step-text"
              >Plug an active cable into one network card to determine which network card it is. </span
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
      <draggable
        v-model="gridData"
        :group="{ name: 'network-rows', pull: 'clone' }"
        class="network-table text-center"
        handle=".drag-handle"
        :animation="300"
        @start="onDragStart"
        @end="onDragEnd"
        @drag="onDrag"
        @drop="onDrop"
      >
        <b-table
          hover
          :items="gridData"
          :fields="tableFields"
          class="network-table text-center"
          bordered
          :striped="false"
          :small="false"
        >
          <!-- Name column -->
          <template #cell(name)="row">
            {{ row.item.name }}
          </template>
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
              ><v-icon>mdi-cursor-move</v-icon>
            </span>
          </template>
          <!-- Device Column -->
          <template #cell(deviceName)="row">
            <b-form-select v-model="row.item.physicalDev" class="custom-dropdown" @change="setInterfacesMap(row.item)">
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

      <!-- Warning Message -->
      <div v-if="gridData.length < 2" class="inline-warning">
        <span class="warning-icon"></span>
        <div>
          <p>
            Untangle must be installed "in-line" as a gateway. This usually requires at least 2 network cards (NICs),
            and fewer than 2 NICs were detected.
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
    </v-container>
  </v-card>
</template>

<script>
  import { mapActions, mapGetters } from 'vuex'
  import Vue from 'vue'
  import { BTable, BFormSelect, BFormSelectOption } from 'bootstrap-vue'
  import { forEach } from 'lodash'
  import VueDraggable from 'vuedraggable'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  import Util from '@/util/setupUtil'
  Vue.use(VueDraggable)

  Vue.component('BTable', BTable)
  Vue.component('BFormSelect', BFormSelect)
  Vue.component('BFormSelectOption', BFormSelectOption)

  export default {
    name: 'Network',
    components: {
      SetupLayout,
    },
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
          { key: 'name', label: 'Name' },
          { key: 'drag', label: 'Drag' },
          { key: 'deviceName', label: 'Device' },
          { key: 'statusIcon', label: 'Icon' },
          { key: 'connected', label: 'Status' },
          { key: 'macAddress', label: 'MAC Address' },
        ],
      }
    },
    computed: {
      ...mapGetters('setup', ['wizardSteps', 'currentStep', 'previousStep']), // from Vuex
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
      ...mapActions('setup', ['setShowStep']), // Map the setShowStep action from Vuex store
      ...mapActions('setup', ['setShowPreviousStep']),

      onDragStart(event) {
        console.log('Drag Started', event)
      },
      onDragEnd(event) {
        console.log('Drag Ended', event)
      },
      onDrag(event) {
        console.log('Dragging...', event)
      },
      onDrop(event) {
        console.log('Item Dropped', event)
      },

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
        sourceRecord.macAddress = targetRecordCopy.macAddress
        sourceRecord.duplex = targetRecordCopy.duplex
        sourceRecord.vendor = targetRecordCopy.vendor
        sourceRecord.mbit = targetRecordCopy.mbit
        sourceRecord.connected = targetRecordCopy.connected

        targetRecord.deviceName = sourceRecordCopy.deviceName
        targetRecord.physicalDev = sourceRecordCopy.physicalDev
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
        } catch (error) {
          this.$vuntangle.toast.add(this.$t(`Failed to fetch device settings: ${error || error.message}`))
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
          const rpc = Util.setRpcJsonrpc('admin')
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
          this.$vuntangle.toast.add(this.$t(`Failed to fetch device status: ${error || error.message}`))
        }
      },

      async onClickBack() {
        try {
          const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)
          await Promise.resolve()
          await this.setShowStep(this.wizardSteps[currentStepIndex - 1])
          await this.setShowPreviousStep(this.wizardSteps[currentStepIndex - 1])
        } catch (error) {
          this.$vuntangle.toast.add(this.$t(`Failed to navigate: ${error || error.message}`))
        }
      },

      async onClickNext() {
        try {
          const interfacesMap = {}
          this.gridData.forEach(function (currentRow) {
            interfacesMap[currentRow.interfaceId] = currentRow.physicalDev
          })

          // apply new physicalDev for each interface from initial Network Settings
          this.networkSettings.interfaces.list.forEach(function (intf) {
            if (!intf.isVlanInterface) {
              intf.physicalDev = interfacesMap[intf.interfaceId]
            }
          })
          const currentStepIndex = await this.wizardSteps.indexOf(this.currentStep)
          await window.rpc.networkManager.setNetworkSettings(this.networkSettings)
          await Promise.resolve()
          await Util.updateWizardSettings(this.currentStep)
          await this.setShowStep(this.wizardSteps[currentStepIndex + 1])
          await this.setShowPreviousStep(this.wizardSteps[currentStepIndex + 1])
        } catch (error) {
          this.$vuntangle.toast.add(this.$t(`Error saving settings: ${error || error.message}`))
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
  .main-div {
    /* max-width: 1100px; */
    display: flex;
    flex-direction: column;
    justify-content: flex-start; /* Align content to the top */
    /* align-items: center; */
    padding: 20px;
    justify-content: flex-start;
    border: 1px solid #ccc;
    border-radius: 5px;
    background-color: #f9f9f9;
    font-family: Arial, sans-serif;
    min-height: 600px; /* Ensures the minimum height remains constant */
    max-height: 700px; /* Prevents the height from changing too much */
    height: 700px; /* Set a fixed height to keep the div consistent */
    position: relative; /* Ensures children stay within boundary */
  }
  .large-font {
    font-size: 17px;
  }
  .network-table {
    width: 100%;
    max-height: 800px;
    border-collapse: collapse;
    box-sizing: border-box;
    /* margin-left: 10px; */
  }

  .network-table td .network-table th {
    border: 2px solid #ccc;
    padding: 10px;
  }
  .network-table.table-bordered {
    border-color: simple-gray(0, 1%, 35%);
  }
  .parent-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    height: 50%;
    border-radius: 5px;
    margin: 10px;
    margin-bottom: -85px;
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
    justify-content: space-between; /* Places Back & Next at extreme left & right */
    align-items: center;
    width: 100%;
    position: absolute;
    bottom: 20px; /* Keeps it at a fixed position from bottom */
    left: 0;
    padding: 10px 20px; /* Adds padding for spacing */

    background-color: #f9f9f9;
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
    margin-left: 10px;
    margin-top: 10px;
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

  .custom-dropdown {
    border: 1px solid #000408;
    border-radius: 2px;
    /* padding-right: 1rem; */
    font-size: 1rem;
    padding-left: 5px;
  }

  .custom-dropdown .custom-dropdown-toggle {
    padding-right: 1.5rem;
  }
</style>
