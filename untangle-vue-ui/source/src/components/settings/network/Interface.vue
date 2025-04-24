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
      row-node-id="device"
      :row-data="rowData"
      :column-defs="colDefs"
      :custom-grid-options="{ suppressRowClickSelection: true }"
      :row-actions="rowActions"
      :framework-components="frameworkComponents"
      v-on="$listeners"
      @row-clicked="onEditInterface"
    />
  </v-container>
</template>

<script>
  import { VContainer, VSpacer, VMenu, VList, VListItem, VListItemTitle, VIcon } from 'vuetify/lib'
  import StatusRenderer from './StatusRenderer.vue'
  import interfaceMixin from './interfaceMixin'
  import Util from '@/util/setupUtil'

  export default {
    components: { VContainer, VSpacer, VMenu, VList, VListItem, VListItemTitle, VIcon },
    mixins: [interfaceMixin],
    props: {
      disabled: { type: Boolean, default: false },
    },
    data() {
      return {
        // all interfaces status, async fetched
        interfacesStatus: undefined,
        physicalDevsStore: [],
        intfOrderArr: [],
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
      }
    },
    computed: {
      // interfaces filered and grouped (by category)
      interfaces() {
        return this.$store.getters['settings/interfaces']
      },
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
            headerName: $i18n.t('Current Address'),
            field: 'ipv4Address',
          },
        ]
      },
      rowData() {
        return this.interfaces?.map(intf => {
          const status = this.interfacesStatusMap?.[intf.device]
          return {
            interfaceId: intf.interfaceId,
            device: intf.physicalDev,
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
      interfacesStatusMap: ({ interfacesStatus }) => {
        if (!interfacesStatus) return
        const map = {}
        interfacesStatus?.forEach(intfStat => {
          map[intfStat.device] = intfStat
        })
        return map
      },
    },
    created() {
      this.$store.dispatch('settings/getInterfaces') // make a call for getInterfaces to populate interfaces data from store
    },
    mounted() {
      this.loadInterfacesAndStatus()
    },
    methods: {
      async loadInterfacesAndStatus() {
        try {
          const rpc = await Util.setRpcJsonrpc('admin')

          // Get Network Settings
          const networkSettings = await rpc.networkManager.getNetworkSettings()
          const interfaces = networkSettings?.interfaces?.list || []

          const filteredInterfaces = interfaces.filter(intf => !intf.isVlanInterface)
          const physicalDevs = filteredInterfaces.map(intf => ({
            physicalDev: intf.physicalDev,
          }))

          // Save to Vue data
          this.interfacesStatus = filteredInterfaces
          this.physicalDevsStore = physicalDevs.map(d => [d.physicalDev, d.physicalDev])

          // Get Device Status
          const deviceStatusData = await rpc.networkManager.getDeviceStatus()
          const deviceStatusList = deviceStatusData?.list || []

          const deviceStatusMap = {}
          deviceStatusList.forEach(dev => {
            deviceStatusMap[dev.deviceName] = dev
          })

          // Map status to interfaces
          this.interfacesStatus = filteredInterfaces.map(intf => {
            const status = deviceStatusMap[intf.physicalDev]
            return {
              ...intf,
              ...(status || {}), // add status fields like 'connected' etc.
            }
          })
        } catch (err) {
          console.error('Error loading interfaces and device status:', err)
          Util.handleException(err)
        }
      },
      /**
       * Emits the edit event up to the host app, used for routing based on device
       * @param {Object} params - row click event params
       * @param {Object} params.data - the row data
       */
      onEditInterface({ data }) {
        // avoid editing an interface if disabled (appliance offline)
        if (this.disabled) return
        this.$emit('edit-interface', data.device)
      },
    },
  }
</script>
