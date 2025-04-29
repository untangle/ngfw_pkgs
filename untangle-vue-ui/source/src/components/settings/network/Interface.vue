<template>
  <v-container class="d-flex flex-column pa-2" fluid>
    <div class="d-flex align-center mb-2">
      <h1 class="headline">{{ $vuntangle.$t('interfaces') }}</h1>
      <v-spacer />
      <v-menu offset-y left>
        <template #activator="{ on, attrs }">
          <u-btn :disabled="disabled" v-bind="attrs" v-on="on">
            {{ $vuntangle.$t('add_interface') }}
            <v-icon small class="ml-1">mdi-chevron-down</v-icon>
          </u-btn>
        </template>
        <v-list dense>
          <v-list-item v-for="item in menuItems" :key="item.to" @click="$emit('add-interface', item.to)">
            <v-list-item-title class="font-weight-bold" v-text="item.text" />
          </v-list-item>
        </v-list>
      </v-menu>
    </div>

    <u-grid
      id="appliance-interfaces"
      row-node-id="rowNodeId"
      :row-data="rowData"
      :column-defs="colDefs"
      :custom-grid-options="gridOptions"
      :row-actions="rowActions"
      :framework-components="frameworkComponents"
      v-on="$listeners"
      @row-clicked="onSelectInterface"
      @grid-ready="onGridReady"
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
      />
    </div>
  </v-container>
</template>

<script>
  import { VContainer, VSpacer, VMenu, VList, VListItem, VListItemTitle, VIcon } from 'vuetify/lib'
  import StatusAndArpEntries from '../interface/StatusAndArpEntries.vue'
  import StatusRenderer from './StatusRenderer.vue'
  import interfaceMixin from './interfaceMixin'
  import Util from '@/util/setupUtil'
  import Rpc from '@/util/Rpc'

  export default {
    components: { VContainer, VSpacer, VMenu, VList, VListItem, VListItemTitle, VIcon, StatusAndArpEntries },
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
        },
        // all interfaces status, async fetched
        interfacesStatus: undefined,
        physicalDevsStore: [],
        intfOrderArr: [],
        selectedInterface: null,
        selectedInterfaceIndex: 0,
        InerfaceDataForVendor: null,
        isResizing: false,
        panelHeight: 500,
        minHeight: 100,
        maxHeight: 800,
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
          macAddress: { displayName: this.$t('MAC Address') },
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
      // interfaces filered and grouped (by category)
      interfaces() {
        return this.$store.getters['settings/interfaces']
      },
      interfaceStatuses() {
        return this.$store.getters['settings/interfaceStatuses']
      },
      // column Header data for Interface Listing
      colDefs: ({ $i18n, deviceValueFormatter, statusValueFormatter }) => {
        return [
          {
            headerName: $i18n.t('Id'),
            field: 'interfaceId',
          },
          {
            headerName: $i18n.t('device'),
            field: 'device',
            sort: 'asc',
            valueFormatter: ({ value }) => deviceValueFormatter(value),
            cellClass: 'primary--text',
            comparator: (a, b) => {
              return a.localeCompare(b, undefined, {
                numeric: true,
                sensitivity: 'base',
              })
            },
          },
          {
            headerName: $i18n.t('Name'),
            field: 'description',
          },
          {
            headerName: $i18n.t('operational_status'),
            field: 'status',
            cellRenderer: 'StatusRenderer',
            valueFormatter: ({ value }) => statusValueFormatter(value),
          },
          {
            headerName: $i18n.t('duplex'),
            field: 'duplex',
          },
          {
            headerName: $i18n.t('Config'),
            field: 'config',
          },
          {
            headerName: $i18n.t('mac_address'),
            field: 'mac',
          },
          {
            headerName: $i18n.t('speed'),
            field: 'speed',
          },
          {
            headerName: $i18n.t('is WAN'),
            field: 'isWan',
          },
          {
            headerName: $i18n.t('Edit'),
            field: 'edit',
            // cellRenderer: () => '<i class="mdi mdi-pencil" style="cursor: pointer;"></i>',
            cellRenderer(params) {
              const icon = document.createElement('i')
              icon.className = 'mdi mdi-pencil'
              icon.style.cursor = 'pointer'
              icon.style.fontSize = '18px'
              icon.title = 'Edit'
              icon.addEventListener('click', event => {
                event.stopPropagation() // Prevents triggering row selection
                params.context.componentParent.onEditInterface(params)
              })
              return icon
            },
            suppressSizeToFit: true,
            suppressMenu: true,
            suppressSorting: true,
            width: 60,
            cellStyle: { textAlign: 'center' },
          },
          {
            headerName: $i18n.t('Current Address'),
            field: 'ipv4Address',
          },
        ]
      },
      // Table data for interface listing table
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
            parentBridge: this.getParentBridge(intf), // delete function dependancy
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
          this.gridApi.deselectAll() // 🔹 important: clear old selection

          const node = this.gridApi.getDisplayedRowAtIndex(newIndex)
          if (node) {
            node.setSelected(true)
            this.onSelectInterface({ data: node.data, node })
          }
        })
      },
    },
    created() {
      this.$store.dispatch('settings/getInterfaces') // make a call for getInterfaces to populate interfaces data from store
      this.$store.dispatch('settings/getNetworkSettings')
      this.$store.dispatch('settings/getInterfaceStatuses')
      console.log('******* interfaces', this.interfaces)
      console.log('*******', this.interfaceStatuses)
    },
    mounted() {
      this.loadSettings()
      // Auto select first row (like `interfacesGridReconfigure`)
      if (this.interfaces) {
        this.InterfacesSelectInitial(this.interfaces[0])
      }
    },
    methods: {
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
          const rpc = await Util.setRpcJsonrpc('admin')

          // Prepare promises for fetching data
          const networkSettingsPromise = rpc.networkManager.getNetworkSettings()
          const interfaceStatusPromise = rpc.networkManager.getInterfaceStatus()
          const deviceStatusPromise = rpc.networkManager.getDeviceStatus()

          const interfaces = networkSettingsPromise?.interfaces?.list || []
          const intfStatusList = interfaceStatusPromise?.list || []
          const devStatusList = deviceStatusPromise?.list || []

          // Filter out VLAN interfaces
          // const filteredInterfaces = interfaces.filter(intf => !intf.isVlanInterface)

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

          // Save final result
          this.interfacesStatus = mergedInterfaces
          // Save physical devices store
          const physicalDevs = mergedInterfaces.map(intf => [intf.physicalDev, intf.physicalDev])
          this.physicalDevsStore = physicalDevs
        } catch (err) {
          console.error('Error loading interfaces and status:', err)
          Util.handleException(err)
        }
      },
      async InterfacesSelectInitial(item) {
        this.selectedInterface = item
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

        this.isLoading = true // Assuming `isLoading` is used to show loader in UI

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
          this.isLoading = false
        }
      },

      async getInterfaceArp(symbolicDev) {
        if (!symbolicDev) {
          this.arpEntries = []
          return
        }

        this.isLoading = true

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
          this.isLoading = false
        }
      },
      async getDynamicRoutingOverview() {
        const vm = this // Assuming you're using `this` to refer to the Vue instance

        const runInterfaceTaskDelay = 100

        // Delay the task to wait for dynamic settings to be populated
        const delayTask = delay => new Promise(resolve => setTimeout(resolve, delay))

        try {
          await delayTask(runInterfaceTaskDelay)

          const networkInterfaces = vm.settings?.interfaces // Access settings and interfaces from the Vue data
          const ospfNetworks = vm.ospfNetworks // Assuming ospfNetworks is also part of your Vue data

          if (!networkInterfaces || !ospfNetworks) {
            await delayTask(runInterfaceTaskDelay)
            return
          }

          const warningsMessages = []

          // Check if dynamic routing is enabled
          if (vm.settings.dynamicRoutingSettings?.enabled) {
            // Check BGP settings
            if (vm.settings.dynamicRoutingSettings.bgpEnabled) {
              if (!vm.settings.dynamicRoutingSettings.bgpNeighbors?.list?.length) {
                warningsMessages.push('At least one BGP neighbor must be configured.')
              }
              if (!vm.settings.dynamicRoutingSettings.bgpNetworks?.list?.length) {
                warningsMessages.push('No BGP networks configured.')
              }
            }

            // Check OSPF settings
            if (vm.settings.dynamicRoutingSettings.ospfEnabled) {
              if (!vm.settings.dynamicRoutingSettings.ospfAreas?.list?.length) {
                warningsMessages.push('At least one OSPF area must be configured.')
              }
              if (!vm.settings.dynamicRoutingSettings.ospfNetworks?.list?.length) {
                warningsMessages.push('No OSPF networks configured.')
              }

              // Check if at least one OSPF network is reachable
              let atLeastOneReachableNetwork = false
              const routingTable = await Rpc.directData('rpc.networkManager.getStatus', 'ROUTING_TABLE', null)

              routingTable.split('\n').forEach(route => {
                if (route.includes(' via ') && !route.includes(' zebra ')) {
                  const routeParts = route.match(/ via ([^\s]+) /)
                  const gateway = routeParts[1]

                  ospfNetworks.forEach(network => {
                    if (network.enabled === true && Util.ipMatchesNetwork(gateway, network.network, network.prefix)) {
                      atLeastOneReachableNetwork = true
                    }
                  })
                }
              })

              if (!atLeastOneReachableNetwork) {
                warningsMessages.push('At least one OSPF network must be reachable.')
              }
            }
          }

          // Update the Vue component's state with the warnings
          vm.dynamicRoutingWarningsMessages = warningsMessages.join('<br>')
          vm.dynamicRoutingWarningsCount = warningsMessages.length
        } catch (error) {
          console.error('Error in getDynamicRoutingOverview:', error)
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
      },
      async onSelectInterface({ data, node }) {
        const index = node ? node.rowIndex : null
        if (index !== null && this.selectedInterfaceIndex !== index) {
          this.selectedInterfaceIndex = index // 🔹 update index so watcher can re-highlight
        }
        this.InerfaceDataForVendor = data?.status?.status
        this.selectedInterface = index
        const symbolicDev = data.symbolicDev || data.device
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
