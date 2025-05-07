<template>
  <v-container>
    <v-card width="1100" class="mx-auto mt-3 pa-3" flat>
      <SetupLayout />
      <div
        v-if="!loadingGridData && gridData.length < 2"
        class="pa-3 mt-4 mx-auto grey lighten-4 border rounded d-flex flex-column"
        style="width: 100%; min-height: 300px; border: 1px solid #e0e0e0 !important; display: flex"
      >
        <span class="mx-2">
          <v-avatar size="12" class="bg-orange-darken-2 mx-2"></v-avatar>
        </span>
        <div>
          <p class="ma-7">
            Untangle must be installed "in-line" as a gateway. This usually requires at least 2 network cards (NICs),
            and fewer than 2 NICs were detected.
          </p>
          <v-checkbox v-model="interfacesForceContinue" density="compact" class="ma-7">
            <template #label>
              <span class="pt-2 d-inline-block">Continue anyway</span>
            </template>
          </v-checkbox>
        </div>
        <div v-if="interfacesForceContinue" class="d-flex justify-space-between pa-2" style="position: relative">
          <u-btn :small="false" @click="onClickBack">{{ `Back` }}</u-btn>
          <u-btn :small="false" @click="onSave">{{ `Next` }}</u-btn>
        </div>
      </div>
      <div
        v-else
        class="pa-3 mt-4 mx-auto grey lighten-4 border rounded d-flex flex-column"
        style="width: 100%; min-height: 500px; border: 1px solid #e0e0e0 !important"
      >
        <div class="ma-2">
          <h1 class="font-weight-light faint-color text-h4">{{ `Identify Network Cards` }}</h1>
          <br />
          <p class="ma-2 font-weight-light faint-color text-h6">
            This step identifies the external, internal, and other network cards.
          </p>

          <div class="ma-2">
            <p>
              <strong>Step 1:</strong>
              <span class="ml-2"
                >Plug an active cable into one network card to determine which network card it is. </span
              ><br />
              <strong>Step 2:</strong>
              <span class="ml-2">Drag and drop the network card to map it to the desired interface.</span>
              <br />
              <strong>Step 3:</strong>
              <span class="ml-2">Repeat steps 1 and 2 for each network card and then click <i>Next</i>.</span>
            </p>
          </div>
          <v-card class="ma-2">
            <v-data-table
              :headers="tableFields"
              :items="gridData"
              item-value="id"
              hide-default-footer
              class="border border-black"
            >
              <template #item="{ item }">
                <tr class="text-center align-middle">
                  <td v-for="(value, key) in item" :key="key" class="text-center align-center">
                    {{ value }}
                  </td>
                </tr>
              </template>
              <template #body>
                <draggable
                  v-model="gridData"
                  :group="{ name: 'network-rows', pull: 'clone' }"
                  tag="tbody"
                  handle=".drag-handle"
                  :move="onBeforeDrop"
                  @start="onDragStart"
                  @end="onDragEnd"
                  @drag="onDrag"
                  @drop="onDrop"
                >
                  <tr v-for="item in gridData" :key="item.id">
                    <td>{{ item.name }}</td>
                    <td>
                      <v-icon class="drag-handle cursor-grab">mdi-drag</v-icon>
                    </td>
                    <td>
                      <v-select
                        v-model="item.physicalDev"
                        :items="deviceStore.map(device => device.physicalDev)"
                        variant="outlined"
                        density="compact"
                        class="bg-grey-lighten-4 text-black border border-black d-flex align-center justify-center"
                        style="width: 80px; height: 36px"
                        menu-icon="mdi-chevron-down"
                        @change="newValue => setInterfacesMap(item, newValue)"
                      ></v-select>
                    </td>
                    <td>
                      <v-avatar size="12" class="mx-3" :class="statusIcon(item.connected)"></v-avatar>
                    </td>
                    <td>{{ getConnectedStr(item) }}</td>
                    <td>{{ item.macAddress }}</td>
                  </tr>
                </draggable>
              </template>
            </v-data-table>
          </v-card>
        </div>
        <div class="d-flex justify-space-between pa-7" style="position: relative">
          <u-btn :small="false" @click="onClickBack">{{ `Back` }}</u-btn>
          <u-btn :small="false" @click="onSave">{{ `Next` }}</u-btn>
        </div>
      </div>
    </v-card>
  </v-container>
</template>

<script>
  import { mapActions, mapGetters } from 'vuex'
  import { forEach } from 'lodash'
  import VueDraggable from 'vuedraggable'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  import Util from '@/util/setupUtil'

  export default {
    name: 'Network',
    components: {
      SetupLayout,
      draggable: VueDraggable,
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
        bordered: true,
        draggedIndex: null,
        draggedItem: null,
        rpcForAdmin: null,
        interfacesForceContinue: false,
        loadingGridData: true,
        tableFields: [
          { text: 'Name', value: 'name', sortable: false },
          { text: 'Drag', value: 'drag', sortable: false },
          { text: 'Device', value: 'deviceName', sortable: false },
          { text: 'Icon', value: 'statusIcon', sortable: false },
          { text: 'Status', value: 'connected', sortable: false },
          { text: 'MAC Address', value: 'macAddress', sortable: false },
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
        this.tempArray = this.gridData.map(item => ({ ...item }))
        this.draggingItem = this.gridData[event.oldIndex]
      },

      onBeforeDrop(event) {
        const newIndex = event.relatedContext.index
        const targetItem = this.tempArray[newIndex]

        if (targetItem) {
          this.draggingItem.physicalDev = targetItem.physicalDev
          this.setInterfacesMap(this.draggingItem)
        }
        return false
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
        this.loadingGridData = true
        this.rpcForAdmin = Util.setRpcJsonrpc('admin')

        this.networkSettings = await new Promise((resolve, reject) => {
          this.rpcForAdmin?.networkManager?.getNetworkSettings((result, ex) => {
            if (ex) {
              Util.handleException('Unable to load interface')
              reject(ex)
            } else {
              resolve(result)
            }
          })
        })
        console.log('this.networkSettings', this.networkSettings)
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

        const deviceRecords = await new Promise((resolve, reject) => {
          this.rpcForAdmin.networkManager.getDeviceStatus((result, ex) => {
            if (ex) {
              Util.handleException(ex)
              reject(ex)
            } else {
              resolve(result)
            }
          })
        })

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
        this.loadingGridData = false
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
        const interfaces = []

        if (!this.rpcForAdmin) {
          this.rpcForAdmin = Util.setRpcJsonrpc('admin')
        }
        await new Promise((resolve, reject) => {
          this.rpcForAdmin.networkManager.getNetworkSettings((result, ex) => {
            if (ex) {
              Util.handleException('Unable to refresh the interfaces')
              reject(ex)
              return
            }
            if (result === null) {
              return
            }
            this.intfListLength = result.interfaces.list.length
            result.interfaces.list.forEach(function (intf) {
              if (!intf.isVlanInterface) {
                interfaces.push(intf)
              }
            })
            if (interfaces.length !== this.gridData.length) {
              alert('There are new interfaces, please restart the wizard.')
              return
            }
            this.rpcForAdmin.networkManager.getDeviceStatus((result2, ex2) => {
              if (ex2) {
                Util.handleException(ex2)
                reject(ex2)
                return
              }
              if (result === null) {
                return
              }
              const deviceStatusMap = result2.list.reduce((map, item) => {
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
              resolve()
            })
          })
        })
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

      async onSave() {
        this.$store.commit('SET_LOADER', true)
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

        await new Promise((resolve, reject) => {
          window.rpc.networkManager.setNetworkSettings((response, ex) => {
            if (ex) {
              Util.handleException(ex)
              this.$store.commit('SET_LOADER', false)
              reject(ex) // Reject the Promise if there's an error
            } else {
              resolve(response) // Resolve the Promise on success
            }
          }, this.networkSettings)
        })

        await Promise.resolve()
        await Util.updateWizardSettings(this.currentStep)
        await this.setShowStep(this.wizardSteps[currentStepIndex + 1])
        await this.setShowPreviousStep(this.wizardSteps[currentStepIndex + 1])

        this.$store.commit('SET_LOADER', false)
      },
      statusIcon(status) {
        return status === 'CONNECTED' ? 'green' : 'grey'
      },
    },
  }
</script>

<style scoped>
  /deep/ th,
  /deep/ td {
    border-right: 1px solid #ddd;
    text-align: center;
    vertical-align: middle;
  }
  /deep/ th:last-child,
  /deep/ td:last-child {
    border-right: none;
  }
</style>
