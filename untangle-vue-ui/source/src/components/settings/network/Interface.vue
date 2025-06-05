<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-2`">
    <div class="d-flex align-center mb-2">
      <h1 class="headline">{{ $vuntangle.$t('interfaces') }}</h1>
      <v-spacer />
      <u-btn :disabled="disabled" class="mr-2" @click="dialogOpen">
        <v-icon small class="ma-2">mdi-shuffle</v-icon>
        {{ `Remap Interfaces` }}
      </u-btn>
      <u-btn :disabled="!allowAddInterfaces" @click="onAddInterface">
        {{ $vuntangle.$t('Add Tagged VLAN Interface') }}
      </u-btn>
    </div>
    <!-- Conditionally shown message (on the basis of allowAddInterfaces) -->
    <div v-if="!allowAddInterfaces" class="mb-3 text-body-2 text-warning">
      {{ $vuntangle.$t('You cannot add new interfaces at this time.') }}
    </div>

    <div
      v-if="tableLoading.interfaces"
      class="d-flex flex-column align-center justify-center pa-6"
      style="height: 200px"
    >
      <v-progress-circular :size="50" :width="4" color="primary" indeterminate />
      <div class="mt-2">{{ $t('Loading...') }}</div>
    </div>
    <u-grid
      v-else
      id="appliance-interfaces"
      row-node-id="rowNodeId"
      :row-data="rowData"
      :column-defs="colDefs"
      :custom-grid-options="gridOptions"
      :row-actions="rowActions"
      :fetching="tableLoading.interfaces"
      :framework-components="frameworkComponents"
      v-on="$listeners"
      @row-clicked="onSelectInterface"
      @grid-ready="onGridReady"
      @refresh="loadSettings"
    />
    <div
      class="resizable-bottom-panel position-relative overflow-hidden"
      :style="{ height: panelHeight + 'px' }"
      @mousemove="onMouseMove"
      @mouseup="stopResize"
    >
      <div class="resize-handle d-flex justify-center align-center" @mousedown.prevent="startResize"></div>
      <StatusAndArpEntries
        :interface-source-config="interfaceSourceConfig"
        :interface-status-data="interfaceStatusData"
        :arp-entries="arpEntries"
        :status-loading="tableLoading.status"
        :arp-loading="tableLoading.arp"
        @refresh-table="handleTableRefresh"
      />
    </div>
  </v-container>
</template>

<script>
  import { VContainer, VSpacer } from 'vuetify/lib'
  import StatusAndArpEntries from '../interface/StatusAndArpEntries.vue'
  import StatusRenderer from './StatusRenderer.vue'
  import interfaceMixin from './interfaceMixin'
  import Util from '@/util/setupUtil'
  import Rpc from '@/util/Rpc'
  import RemapConfirmDialog from '@/components/Reusable/RemapInterfaceDialogue.vue'
  import ConfirmDialog from '@/components/Reusable/ConfirmDialog.vue'

  export default {
    components: { VContainer, VSpacer, StatusAndArpEntries },
    mixins: [interfaceMixin],
    props: {
      disabled: { type: Boolean, default: false },
    },
    data() {
      return {
        gridOptions: {
          context: {
            componentParent: this,
          },
          suppressRowClickSelection: true,
          rowSelection: 'single',
          dialog: false,
        },
        // all interfaces status, async fetched
        interfacesStatus: undefined,
        adminRpc: null,
        physicalDevsStore: [],
        interfaces: [],
        intfOrderArr: [],
        selectedInterface: null,
        selectedInterfaceIndex: 0,
        InerfaceDataForVendor: null,
        symbolicDev: null,
        isResizing: false,
        panelHeight: 500,
        minHeight: 100,
        maxHeight: 800,
        allowAddInterfaces: null,
        tableLoading: {
          interfaces: false,
          status: false,
          arp: false,
        },
        features: {
          hasWireguard: false,
          hasOpenVpn: false,
          hasBridged: false,
        },
        frameworkComponents: {
          StatusRenderer,
        },
        rowActions: [
          {
            icon: 'mdi-delete',
            handler: ({ data }) => this.$emit('delete-interface', data.device),
            isHidden: ({ data }) => {
              return ['NIC', 'WIFI', 'WWAN'].includes(data.originalType) || data.parentBridge !== '-'
            },
          },
        ],
        interfaceSourceConfig: {
          address: { displayName: this.$t('IPv4 Address') },
          device: { displayName: this.$t('Device') },
          rxbytes: { displayName: this.$t('Rx Bytes') },
          rxdrop: { displayName: this.$t('Rx Drop') },
          rxpkts: { displayName: this.$t('Rx Packets') },
          rxerr: { displayName: this.$t('Rx Errors') },
          txbytes: { displayName: this.$t('Tx Bytes') },
          txdrop: { displayName: this.$t('Tx Drop') },
          txerr: { displayName: this.$t('Tx Errors') },
          txpkts: { displayName: this.$t('Tx Packets') },
          v6Addr: { displayName: this.$t('IPv6 Address') },
          vendor: { displayName: this.$t('MAC Vendor') },
        },
        interfaceStatusData: {},
        arpEntries: [],
        interfaceStatusLinkMap: {
          1: 'macAddress',
          2: 'rxbytes',
          3: 'rxpkts',
          4: 'rxerr',
          5: 'rxdrop',
          8: 'txbytes',
          9: 'txpkts',
          10: 'txerr',
          11: 'txdrop',
        },
      }
    },
    computed: {
      interfaceStatuses() {
        return this.$store.getters['settings/interfaceStatuses']
      },
      // column Header data for Interface Listing
      colDefs: ({ $i18n, deviceValueFormatter, statusValueFormatter }) => {
        return [
          {
            headerName: $i18n.t('Id'),
            field: 'interfaceId',
            sort: 'asc',
            minWidth: 70,
            comparator: (a, b) => Number(a) - Number(b), // sort Interfaces  on the basis of ID
          },
          {
            headerName: $i18n.t('Name'),
            field: 'description',
            flex: 1,
            // functionality for tooltip
            cellRenderer(params) {
              const value = params.value || '-'
              const span = document.createElement('span')

              span.innerText = value
              span.title = value
              span.style.whiteSpace = 'nowrap'
              span.style.overflow = 'hidden'
              span.style.textOverflow = 'ellipsis'
              span.style.display = 'block'
              span.style.width = '100%'

              return span
            },
          },
          {
            headerName: $i18n.t('device'),
            field: 'device',
            valueFormatter: ({ value }) => deviceValueFormatter(value),
            cellClass: 'primary--text',
            comparator: (a, b) => {
              return a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' })
            },
          },

          {
            headerName: $i18n.t('operational_status'),
            field: 'status',
            cellRenderer: 'StatusRenderer',
            minWidth: 150,
            valueFormatter: ({ value }) => statusValueFormatter(value),
          },
          {
            headerName: $i18n.t('duplex'),
            field: 'duplex',
            minWidth: 150,
          },
          {
            headerName: $i18n.t('Config'),
            field: 'config',
            minWidth: 150,
          },
          {
            headerName: $i18n.t('speed'),
            field: 'speed',
            minWidth: 120,
          },
          {
            headerName: $i18n.t('is WAN'),
            field: 'isWan',
            minWidth: 100,
          },
          {
            headerName: $i18n.t('Current Address'),
            field: 'ipv4Address',
          },
          {
            headerName: $i18n.t('Edit'),
            field: 'edit',
            cellRenderer(params) {
              const icon = document.createElement('i')
              icon.className = 'mdi mdi-pencil'
              icon.style.cursor = 'pointer'
              icon.style.fontSize = '18px'
              icon.title = 'Edit'
              icon.addEventListener('click', event => {
                event.stopPropagation()
                params.context.componentParent.onEditInterface(params)
              })
              return icon
            },
            suppressSizeToFit: true,
            width: 100,
            minWidth: 100,
            maxWidth: 100,
            suppressMenu: true,
            cellStyle: { textAlign: 'center' },
          },
          {
            headerName: $i18n.t('Delete'),
            field: 'delete',
            cellRenderer(params) {
              const icon = document.createElement('i')
              icon.className = 'mdi mdi-delete'
              icon.style.fontSize = '18px'
              icon.title = 'Delete'
              // ----- Conditional logic -----
              const isVlanInterface = params.data.status?.intf?.isVlanInterface
              const isMissing = params.data.status?.status?.connected === 'MISSING'

              const isDisabled = !(isVlanInterface || isMissing)

              if (isDisabled) {
                icon.style.opacity = '0.3'
                icon.style.cursor = 'not-allowed'
              } else {
                icon.style.cursor = 'pointer'
                icon.addEventListener('click', event => {
                  event.stopPropagation()
                  params.context.componentParent.onDeleteInterface(params.data)
                })
              }

              return icon
            },
            suppressSizeToFit: true,
            suppressMenu: true,
            width: 100,
            minWidth: 100,
            maxWidth: 100,
            cellStyle: { textAlign: 'center' },
          },
        ]
      },

      // Table data for interface listing table
      // rowData iterate interface object
      rowData() {
        return this.interfaces?.map(intf => {
          const status = this.interfacesStatusMap?.[intf.symbolicDev]
          return {
            rowNodeId: intf.interfaceId,
            interfaceId: intf.interfaceId,
            device: this.deviceRenderer(intf),
            description: intf.name,
            status: this.getStatus(intf, status),
            config: this.getConfigAddress(intf, status),
            duplex: this.getDuplex(intf, status),
            mac: this.getMac(intf, status),
            speed: this.getSpeed(intf, status),
            isWan: this.getIsWan(intf, status),
            ipv4Address: this.getIpv4Address(intf, status),
            type: this.getType(intf),
            originalType: intf.type,
          }
        })
      },
      /**
       * Returns a map of interfaces status based on interface device
       * @param {Object} vm - vue instance
       * @param {Object} vm.interfacesStatus - all interfaces status
       * @returns {Object} - the status mapped by interface device
       */

      menuItems: ({ features, $i18n }) => {
        return [
          ...(features.hasOpenVpn ? [{ text: $i18n.t('open_vpn'), to: 'openvpn' }] : []),
          ...(features.hasWireguard ? [{ text: $i18n.t('wireguard'), to: 'wireguard' }] : []),
          { text: $i18n.t('vlan'), to: 'vlan' },
          { text: $i18n.t('ipsec_tunnel'), to: 'ipsec' },
          ...(features.hasBridged ? [{ text: $i18n.t('bridge'), to: 'bridge' }] : []),
        ]
      },
      interfacesStatusMap({ interfacesStatus }) {
        if (!interfacesStatus) return {}

        const map = {}
        interfacesStatus.forEach(intfStat => {
          if (intfStat.symbolicDev) {
            map[intfStat.symbolicDev] = intfStat
          }
        })

        return map
      },
    },
    watch: {
      selectedInterfaceIndex(newIndex) {
        if (!this.gridApi) return

        this.$nextTick(() => {
          this.gridApi.deselectAll() // clear old selection

          const node = this.gridApi.getDisplayedRowAtIndex(newIndex)
          if (node) {
            node.setSelected(true)
            this.onSelectInterface({ data: node.data, node })
          }
        })
      },
    },
    async created() {
      try {
        this.adminRpc = await Util.setRpcJsonrpc('admin')
      } catch (ex) {
        Util.handleException(ex)
      }
      this.$store.dispatch('settings/getInterfaces') // update interfaces in the store
      this.$store.dispatch('settings/getNetworkSettings')
      this.$store.dispatch('settings/getInterfaceStatuses')
    },
    async mounted() {
      this.$store.commit('settings/setEditCallback', this.loadSettings)
      await this.loadSettings()

      if (this.interfaces && this.interfaces.length > 0) {
        this.InterfacesSelectInitial(this.interfaces[0])
      }
    },
    methods: {
      RemapConfirmDialog({ parentInterfaces, onConfirmNo = null, onConfirmYes = null }) {
        let dialogComponentRef = null
        this.$vuntangle.dialog.show({
          title: this.$t('Remap Interfaces'),
          component: RemapConfirmDialog,
          componentProps: {
            alert: { parentInterfaces },
            setRef: ref => (dialogComponentRef = ref),
          },
          width: 1000,
          height: 800,
          on: {
            confirm: updatedInterfaces => {
              this.$nextTick(() => {
                onConfirmYes(updatedInterfaces)
              })
            },
          },
          buttons: [
            {
              name: this.$t('Done'),
              async handler() {
                if (dialogComponentRef?.done) {
                  const updatedInterfaces = dialogComponentRef.gridData
                  try {
                    await onConfirmYes(updatedInterfaces)
                    this.onClose()
                  } catch (e) {
                    Util.handleException(e)
                  }
                  dialogComponentRef.done()
                }
              },
            },
            {
              name: this.$t('Cancel'),
              handler() {
                this.onClose()
                onConfirmNo()
              },
            },
          ],
        })
      },
      dialogOpen() {
        const originalInterfaces = JSON.stringify(this.interfaces)
        this.RemapConfirmDialog({
          parentInterfaces: this.interfaces,
          onConfirmYes: async updatedInterfacesFromRemap => {
            try {
              // Update settings only if remapping is done
              if (JSON.stringify(updatedInterfacesFromRemap) !== originalInterfaces) {
                await this.$store.dispatch('settings/setInterfaces', updatedInterfacesFromRemap)
              }
              this.loadSettings()
            } catch (error) {
              Util.handleException(error)
            }
          },
          onConfirmNo: () => {
            this.loadSettings()
          },
        })
      },
      startResize() {
        this.isResizing = true
        document.addEventListener('mousemove', this.onMouseMove)
        document.addEventListener('mouseup', this.stopResize)
      },
      onMouseMove(e) {
        if (!this.isResizing) return
        const containerBottom = this.$el.getBoundingClientRect().bottom
        const newHeight = containerBottom - e.clientY
        if (newHeight >= this.minHeight && newHeight <= this.maxHeight) {
          this.panelHeight = newHeight
        }
      },
      stopResize() {
        this.isResizing = false
        document.removeEventListener('mousemove', this.onMouseMove)
        document.removeEventListener('mouseup', this.stopResize)
      },

      async loadSettings() {
        try {
          this.tableLoading.interfaces = true
          const rpc = await Util.setRpcJsonrpc('admin')

          // Prepare promises for fetching data
          const networkSettingsPromise = await rpc.networkManager.getNetworkSettings()
          const interfaceStatusPromise = await rpc.networkManager.getInterfaceStatus()
          const deviceStatusPromise = await rpc.networkManager.getDeviceStatus()
          const nextFreeId = await rpc.networkManager.getNextFreeInterfaceId(networkSettingsPromise)
          const interfaces = networkSettingsPromise?.interfaces?.list || []
          const intfStatusList = interfaceStatusPromise?.list || []
          const devStatusList = deviceStatusPromise?.list || []
          this.allowAddInterfaces = nextFreeId !== -1
          const deviceStatusMap = {}
          devStatusList.forEach(dev => {
            deviceStatusMap[dev.deviceName] = dev
          })

          const interfaceStatusMap = {}
          intfStatusList.forEach(intfStatus => {
            interfaceStatusMap[intfStatus.interfaceId] = intfStatus
          })

          // Merge interface status and device status into interfaces
          const mergedInterfaces = interfaces.map(intf => {
            const intfStatus = interfaceStatusMap[intf.interfaceId]
            const devStatus = deviceStatusMap[intf.physicalDev]

            if (intfStatus) {
              delete intfStatus.javaClass
              Object.assign(intf, intfStatus)
            }

            if (devStatus) {
              delete devStatus.javaClass
              Object.assign(intf, devStatus)
            }

            return intf
          })
          this.interfaces = mergedInterfaces
          // Save final result
          this.interfacesStatus = mergedInterfaces
          // Save physical devices store
          const physicalDevs = mergedInterfaces.map(intf => [intf.physicalDev, intf.physicalDev])
          this.physicalDevsStore = physicalDevs
        } catch (err) {
          Util.handleException(err)
        } finally {
          this.tableLoading.interfaces = false
        }
      },
      async InterfacesSelectInitial(item) {
        this.selectedInterface = item
        const symbolicDev = item.symbolicDev
        this.symbolicDev = symbolicDev
        await this.getInterfaceStatus(item.symbolicDev)
        await this.getInterfaceArp(item.symbolicDev)
      },

      async getInterfaceStatus(symbolicDev) {
        // Simulate loading in the status grid
        this.siStatus = { device: '' }

        if (!symbolicDev) {
          this.siStatus = {}
          return
        }
        this.tableLoading.status = true

        try {
          const res1Promise = Rpc.asyncPromise('rpc.networkManager.getStatus', 'INTERFACE_TRANSFER', symbolicDev)
          const res2Promise = Rpc.asyncPromise('rpc.networkManager.getStatus', 'INTERFACE_IP_ADDRESSES', symbolicDev)

          const [res1, res2] = await Promise.all([res1Promise(), res2Promise()])

          const stat = {
            device: symbolicDev,
            macAddress: null,
            address: null,
            v6Addr: null,
            rxpkts: null,
            rxbytes: null,
            rxerr: null,
            rxdrop: null,
            txpkts: null,
            txbytes: null,
            txerr: null,
            txdrop: null,
            vendor: this.InerfaceDataForVendor?.vendor || null,
          }
          if (this.interfaceStatusLinkMap) {
            res1
              .trim()
              .split(' ')
              .forEach((item, index) => {
                if (index in this.interfaceStatusLinkMap) {
                  stat[this.interfaceStatusLinkMap[index]] = item
                }
              })
          }

          let getNext = false
          res2.split(' ').forEach(item => {
            if (getNext) {
              stat[getNext] = stat[getNext] ? [...stat[getNext], item] : [item]
              getNext = false
            }
            if (item === 'inet') getNext = 'address'
            else if (item === 'inet6') getNext = 'v6Addr'
          })
          stat.address = Array.isArray(stat.address) ? stat.address.join(', ') : stat.address
          stat.v6Addr = Array.isArray(stat.v6Addr) ? stat.v6Addr.join(', ') : stat.v6Addr

          // Apply datasize renderer
          stat.rxbytes = stat.rxbytes !== null ? this.datasize(stat.rxbytes) : null
          stat.txbytes = stat.txbytes !== null ? this.datasize(stat.txbytes) : null

          // Apply count renderer
          stat.rxpkts = stat.rxpkts !== null ? this.count(stat.rxpkts) : null
          stat.rxerr = stat.rxerr !== null ? this.count(stat.rxerr) : null
          stat.rxdrop = stat.rxdrop !== null ? this.count(stat.rxdrop) : null
          stat.txpkts = stat.txpkts !== null ? this.count(stat.txpkts) : null
          stat.txerr = stat.txerr !== null ? this.count(stat.txerr) : null
          stat.txdrop = stat.txdrop !== null ? this.count(stat.txdrop) : null
          this.siStatus = stat
          this.interfaceStatusData = this.siStatus
        } catch (err) {
          console.error('Interface Status Error:', err)
          this.siStatus = {}
        } finally {
          this.tableLoading.status = false
        }
      },

      async getInterfaceArp(symbolicDev) {
        if (!symbolicDev) {
          this.arpEntries = []
          return
        }

        this.tableLoading.arp = true

        try {
          const result = await Rpc.asyncData('rpc.networkManager.getStatus', 'INTERFACE_ARP_TABLE', symbolicDev)
          const connections = []
          const macAddressList = []

          result.split('\n').forEach(row => {
            if (row.trim() === '') return

            const items = row.trim().split(/\s+/) // Split by whitespace
            const address = items[0] || null
            const macAddress = items[2] || null

            if (macAddress) macAddressList.push(macAddress)

            connections.push({
              address,
              macAddress,
              vendor: null,
            })
          })

          if (macAddressList.length > 0) {
            const list = { javaClass: 'java.util.LinkedList', list: macAddressList }
            const lookUpResult = await Rpc.directData('rpc.networkManager.lookupMacVendorList', list)
            const macVendorMap = lookUpResult.map || {}

            connections.forEach(conn => {
              if (macVendorMap[conn.macAddress]) {
                conn.vendor = macVendorMap[conn.macAddress]
              }
            })
          }

          this.arpEntries = connections
        } catch (err) {
          console.error('Failed to fetch ARP table:', err)
          Util.handleException(err)
        } finally {
          this.tableLoading.arp = false
        }
      },

      async handleTableRefresh(source) {
        if (!this.symbolicDev) return
        if (source === 'status') {
          await this.getInterfaceStatus(this.symbolicDev)
        } else if (source === 'arp') {
          await this.getInterfaceArp(this.symbolicDev)
        }
      },
      /**
       * Emits the edit event up to the host app, used for routing based on device
       * @param {Object} params - row click event params
       * @param {Object} params.data - the row data
       */
      onEditInterface(rowData) {
        this.intf = rowData.data
        this.$router.push(`/settings/network/interfaces/${rowData.data.device}`)
      },

      onAddInterface() {
        this.$router.push(`/settings/network/interfaces/add/VLAN`)
      },

      async onDeleteInterface(rowData) {
        const isVlanInterface = rowData?.status?.intf?.isVlanInterface
        const connectedStatus = rowData?.status?.status?.connected
        const name = rowData?.description || rowData?.status?.intf?.name

        let msg = ''
        if (isVlanInterface) msg = 'Delete VLAN Interface'
        else if (connectedStatus === 'MISSING') msg = 'Delete Missing Interface'
        else msg = 'Delete Interface'

        const confirmed = await this.confirmDialog({
          message: `Are you sure you want to delete <strong>${name}</strong>?`,
          title: msg,
        })

        if (confirmed) {
          await this.deleteInterface(rowData)
        }
      },
      // In Ext JS saveSettings & setNetworkSettings which used for save overall setting data while updating anything.
      // In Vue we are deleting interface updating deleteed interfaceslist with setting
      // So while deleing Interfaces we update setting and pass it to the api call

      async deleteInterface(rowData) {
        const deletedId = rowData?.interfaceId || rowData?.status?.intf?.interfaceId
        if (!deletedId) return

        const updatedInterfaces = this.interfaces.filter(intf => intf.interfaceId !== deletedId)
        this.interfaces = updatedInterfaces

        try {
          this.tableLoading.interfaces = true

          await this.$store.dispatch('settings/deleteInterfaces', updatedInterfaces)
          this.$vuntangle.toast.add('Network settings saved successfully!')
          await this.loadSettings()
        } catch (error) {
          this.$vuntangle.toast.add('Failed to delete interface. Please try again.')
        } finally {
          this.tableLoading.interfaces = false
        }
      },

      confirmDialog({ message }) {
        return new Promise(resolve => {
          this.$vuntangle.dialog.show({
            title: this.$t('Delete VLAN Interface'),
            component: ConfirmDialog,
            componentProps: {
              alert: { message },
            },
            width: 600,
            height: 500,
            buttons: [
              {
                name: this.$t('Yes'),
                handler() {
                  this.onClose()
                  resolve(true)
                },
              },
              {
                name: this.$t('No'),
                handler() {
                  this.onClose()
                  resolve(false)
                },
              },
            ],
          })
        })
      },
      onGridReady(params) {
        this.gridApi = params.api
        this.gridColumnApi = params.columnApi

        this.$nextTick(() => {
          const firstNode = this.gridApi.getDisplayedRowAtIndex(this.selectedInterfaceIndex)
          if (firstNode) {
            firstNode.setSelected(true)
            this.onSelectInterface({ data: firstNode.data, node: firstNode })
          }
        })
        // Auto-size all columns
        this.gridApi.sizeColumnsToFit()
      },
      async onSelectInterface({ data, node }) {
        const index = node ? node.rowIndex : null
        if (index !== null && this.selectedInterfaceIndex !== index) {
          this.selectedInterfaceIndex = index //  update index so watcher can re-highlight
        }
        this.InerfaceDataForVendor = data?.status?.status
        this.selectedInterface = index
        const symbolicDev = data.symbolicDev || data.device
        this.symbolicDev = symbolicDev
        if (!symbolicDev) return
        await this.getInterfaceStatus(symbolicDev)
        await this.getInterfaceArp(symbolicDev)
      },
    },
  }
</script>

<style scoped>
  .resizable-bottom-panel {
    border-top: 1px solid #ccc;
  }

  .resize-handle {
    height: 7px;
    cursor: row-resize;
    background-color: #ddd;
    user-select: none;
  }
</style>
