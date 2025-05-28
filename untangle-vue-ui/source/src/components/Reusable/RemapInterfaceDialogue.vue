<template>
  <v-card class="mx-auto pa-2" max-width="100%" elevation="2">
    <div style="overflow: auto" class="ma-2">
      <p class="ma-2 font-weight-light faint-color text-h6">
        <strong>How to map Devices with Interfaces</strong>
      </p>

      <div class="ma-2">
        <p>
          <strong>Method 1:</strong><b> Drag and Drop</b><span class="ml-1">the Device to the desired Interface </span
          ><br />
          <strong>Method 2:</strong><b> Click on a Device</b>
          <span class="ml-1"
            >to open a combo and choose the desired Device from a list. When another Device is selected the 2 Devices
            are switched.</span
          >
        </p>
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
                  <td>
                    <v-avatar size="12" class="mx-3" :class="statusIcon(item.connected)"></v-avatar>
                  </td>
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
                      @change="newValue => setMapInterfaces(item, newValue)"
                    ></v-select>
                  </td>
                  <td>{{ item.mbit }}</td>
                  <td>{{ getDuplex(item) }}</td>
                  <td>{{ getVendor(item) }}</td>
                  <td v-html="renderMacAddress(item.macAddress)"></td>
                </tr>
              </draggable>
            </template>
          </v-data-table>
        </v-card>
      </div>
    </div>
  </v-card>
</template>

<script>
  import VueDraggable from 'vuedraggable'
  import { forEach } from 'lodash'
  import Util from '../../util/setupUtil'

  export default {
    components: {
      draggable: VueDraggable,
    },
    props: {
      alert: {
        type: Object,
        required: true,
      },
      setRef: Function,
    },
    data() {
      return {
        gridData: [],
        tempArray: [],
        deviceStore: [],
        intfOrderArr: [],
        draggingItem: null,
        intfListLength: 0,
        enableAutoRefresh: true,
        bordered: true,
        draggedIndex: null,
        draggedItem: null,
        rpcForAdmin: null,
        interfacesForceContinue: false,
        tableFields: [
          { text: 'Icon', value: 'statusIcon', sortable: false },
          { text: 'Name', value: 'name', sortable: false },
          { text: 'Drag', value: 'drag', sortable: false },
          { text: 'Device', value: 'deviceName', sortable: false },
          { text: 'Speed', value: 'name', sortable: false },
          { text: 'Duplex', value: 'name', sortable: false },
          { text: 'Vendor', value: 'connected', sortable: false },
          { text: 'MAC Address', value: 'macAddress', sortable: false },
        ],
      }
    },
    mounted() {
      this.setRef?.(this)
    },
    created() {
      this.remapInterfaces()
    },
    methods: {
      done() {
        this.$emit('confirm', this.gridData)
      },
      async remapInterfaces() {
        this.rpcForAdmin = Util.setRpcJsonrpc('admin')
        const physicalDevsStore = []
        this.intfOrderArr = []
        this.intfListLength = this.alert.parentInterfaces.length
        const interfaces = []
        const devices = []

        forEach(this.alert.parentInterfaces, intf => {
          if (!intf.isVlanInterface) {
            interfaces.push(intf)
            devices.push({ physicalDev: intf.physicalDev })
            this.intfOrderArr.push({ ...intf })
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
      },
      onDragStart(event) {
        this.tempArray = this.gridData.map(item => ({ ...item }))
        this.draggingItem = this.gridData[event.oldIndex]
      },

      onBeforeDrop() {
        return true
      },
      onDragEnd() {
        let i = 0
        this.gridData.forEach(currentRow => {
          const intf = this.intfOrderArr[i]
          currentRow.interfaceId = intf.interfaceId
          currentRow.name = intf.name
          i++
        })
        return false
      },
      onDrag(event) {
        console.log('Dragging...', event)
      },
      onDrop(event) {
        console.log('Item Dropped', event)
      },

      getVendor(item) {
        const vendor = item.vendor
        return vendor
      },

      getDuplex(item) {
        const duplex = item.duplex
        return duplex === 'FULL_DUPLEX' ? 'full-duplex' : duplex === 'HALF_DUPLEX' ? 'half-duplex' : 'unknown'
      },

      renderMacAddress(mac) {
        if (mac && mac.length > 0) {
          const searchPrefix = mac.substring(0, 8).replace(/:/g, '')
          const href = `http://standards.ieee.org/cgi-bin/ouisearch?${searchPrefix}`
          return `<a href="${href}" target="_blank">${mac}</a>`
        }
        return '-'
      },

      // used when mapping from comboboxes
      setMapInterfaces(row) {
        const oldValue = row.deviceName
        const newValue = row.physicalDev

        const sourceIndex = this.gridData.findIndex(intf => intf.deviceName === oldValue)
        const targetIndex = this.gridData.findIndex(intf => intf.deviceName === newValue)

        if (sourceIndex === -1 || targetIndex === -1 || sourceIndex === targetIndex) {
          return
        }

        const source = this.gridData[sourceIndex]
        const target = this.gridData[targetIndex]

        // Only swap properties EXCLUDING 'interfaceId' and 'name'
        const keysToSwap = Object.keys(source).filter(key => !['interfaceId', 'name'].includes(key))
        keysToSwap.forEach(key => {
          const temp = source[key]
          source[key] = target[key]
          target[key] = temp
        })

        // Ensure deviceName and physicalDev are updated accordingly
        source.deviceName = newValue
        source.physicalDev = newValue
        target.deviceName = oldValue
        target.physicalDev = oldValue

        // Apply the same to intfOrderArr
        const sourceIntf = this.intfOrderArr[sourceIndex]
        const targetIntf = this.intfOrderArr[targetIndex]

        if (sourceIntf && targetIntf) {
          const intfKeysToSwap = Object.keys(sourceIntf).filter(key => !['interfaceId', 'name'].includes(key))
          intfKeysToSwap.forEach(key => {
            const temp = sourceIntf[key]
            sourceIntf[key] = targetIntf[key]
            targetIntf[key] = temp
          })

          sourceIntf.deviceName = newValue
          sourceIntf.physicalDev = newValue
          targetIntf.deviceName = oldValue
          targetIntf.physicalDev = oldValue
        }
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
