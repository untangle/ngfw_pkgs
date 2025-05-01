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
      :framework-components="frameworkComponents"
      v-on="$listeners"
      @row-clicked="onEditInterface"
    />
  </v-container>
</template>
<script>
  import { VContainer, VSpacer, VMenu, VList, VListItem, VListItemTitle, VIcon } from 'vuetify/lib'
  // import StatusRenderer from './StatusRenderer.vue'
  import interfacesMixin from './interfacesMixin'

  export default {
    components: { VContainer, VSpacer, VMenu, VList, VListItem, VListItemTitle, VIcon },
    mixins: [interfacesMixin],

    props: {
      // interfaces settings from box settings.json
      interfaces: { type: Array, required: true },
      // interfaces status
      interfacesStatus: { type: Array, default: undefined },
      // features that applies to interfaces view
      features: { type: Object, default: undefined },
      // weather the applliance is offline
      disabled: { type: Boolean, default: false },
    },

    data() {
      return {
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
      colDefs() {
        return [
          {
            headerName: this.$i18n.t('interface'),
            field: 'device',
            sort: 'asc',
            cellClass: 'primary--text',
            comparator: (a, b) => {
              return a.localeCompare(b, undefined, {
                numeric: true,
                sensitivity: 'base',
              })
            },
          },
          {
            headerName: this.$i18n.t('description'),
            field: 'description',
          },
          {
            headerName: this.$i18n.t('operational_status'),
            field: 'status',
          },
          {
            headerName: this.$i18n.t('duplex'),
            field: 'duplex',
          },
          {
            headerName: this.$i18n.t('mac_address'),
            field: 'mac',
          },
          {
            headerName: this.$i18n.t('mtu'),
            field: 'mtu',
          },
          {
            headerName: this.$i18n.t('speed'),
            field: 'speed',
          },
          {
            headerName: this.$i18n.t('type'),
            field: 'type',
          },
          {
            headerName: this.$i18n.t('ipv4_address'),
            field: 'ipv4Address',
          },
          {
            headerName: this.$i18n.t('ipv4_gateway'),
            field: 'ipv4Gateway',
            hide: true,
          },
          {
            headerName: this.$i18n.t('ipv6_address'),
            field: 'ipv6Address',
          },
          {
            headerName: 'Edit',
            field: '<v-icon>{{ icons.mdiPencil }}</v-icon>',
            hide: true,
          },
          {
            headerName: 'Edit',
            field: 'edit',
            cellRenderer: () => '<i class="mdi mdi-pencil" style="cursor: pointer;"></i>',
          },
          {
            headerName: this.$i18n.t('dns_servers'),
            field: 'dnsServers',
            hide: true,
          },
          {
            headerName: this.$i18n.t('download'),
            field: 'download',
            hide: true,
          },
        ]
      },

      // colDefs: ({ $i18n, deviceValueFormatter, statusValueFormatter }) => {
      //   return [
      //     {
      //       headerName: $i18n.t('interface'),
      //       field: 'device',
      //       sort: 'asc',
      //       valueFormatter: ({ value }) => deviceValueFormatter(value),
      //       cellClass: 'primary--text',
      //       comparator: (a, b) => {
      //         return a.localeCompare(b, undefined, {
      //           numeric: true,
      //           sensitivity: 'base',
      //         })
      //       },
      //     },
      //     {
      //       headerName: $i18n.t('description'),
      //       field: 'description',
      //     },
      //     {
      //       headerName: $i18n.t('operational_status'),
      //       field: 'status',
      //       cellRenderer: 'StatusRenderer',
      //       valueFormatter: ({ value }) => statusValueFormatter(value),
      //     },
      //     {
      //       headerName: $i18n.t('duplex'),
      //       field: 'duplex',
      //     },
      //     {
      //       headerName: $i18n.t('mac_address'),
      //       field: 'mac',
      //     },
      //     {
      //       headerName: $i18n.t('mtu'),
      //       field: 'mtu',
      //     },
      //     {
      //       headerName: $i18n.t('speed'),
      //       field: 'speed',
      //     },
      //     {
      //       headerName: $i18n.t('type'),
      //       field: 'type',
      //     },
      //     {
      //       headerName: $i18n.t('ipv4_address'),
      //       field: 'ipv4Address',
      //     },
      //     {
      //       headerName: $i18n.t('ipv4_gateway'),
      //       field: 'ipv4Gateway',
      //       hide: true,
      //     },
      //     {
      //       headerName: $i18n.t('ipv6_address'),
      //       field: 'ipv6Address',
      //     },
      //     {
      //       headerName: $i18n.t('ipv6_gateway'),
      //       field: 'ipv6Gateway',
      //       hide: true,
      //     },
      //     {
      //       headerName: $i18n.t('dns_servers'),
      //       field: 'dnsServers',
      //       hide: true,
      //     },
      //     {
      //       headerName: $i18n.t('download'),
      //       field: 'download',
      //       hide: true,
      //     },
      //     {
      //       headerName: $i18n.t('upload'),
      //       field: 'upload',
      //       hide: true,
      //     },
      //     {
      //       headerName: $i18n.t('bridged_to'),
      //       field: 'bridgedTo',
      //       hide: true,
      //     },
      //     {
      //       headerName: $i18n.t('parent_bridge'),
      //       field: 'parentBridge',
      //       hide: true,
      //     },
      //     // IPsec specific columns
      //     {
      //       headerName: `IPsec ${$i18n.t('local_gateway')}`,
      //       field: 'ipsecLocalGateway',
      //       hide: true,
      //     },
      //     {
      //       headerName: `IPsec ${$i18n.t('local_networks')}`,
      //       field: 'ipsecLocalNetworks',
      //       hide: true,
      //     },
      //     {
      //       headerName: `IPsec ${$i18n.t('remote_gateway')}`,
      //       field: 'ipsecRemoteGateway',
      //       hide: true,
      //     },
      //     {
      //       headerName: `IPsec ${$i18n.t('remote_networks')}`,
      //       field: 'ipsecRemoteNetworks',
      //       hide: true,
      //     },
      //     {
      //       headerName: `IPsec ${$i18n.t('bound_to')}`,
      //       field: 'ipsecBoundTo',
      //       hide: true,
      //     },
      //     {
      //       headerName: `IPsec ${$i18n.t('authentication')}`,
      //       field: 'ipsecAuthType',
      //       hide: true,
      //     },
      //   ]
      // },

      /**
       * Returns grid data formatted for display based on interface settings and interface status
       */
      rowData() {
        return [
          {
            device: 'eth0',
            description: 'internal',
            status: 'connected',
            duplex: 'Full-duplex',
            mac: '00:11:22:33:44:55',
            mtu: 1500,
            speed: '1 Gbit',
            type: 'NIC',
            originalType: 'NIC',
            download: '100 Mbps',
            upload: '50 Mbps',
            ipv4Address: '192.168.1.6',
            ipv4Gateway: '192.168.1.1',
            ipv6Address: 'fe80::1',
            ipv6Gateway: 'fe80::ffff',
            dnsServers: ['8.8.8.8', '8.8.4.4'],
            bridgedTo: '-',
            parentBridge: '-',
            ipsecLocalGateway: '10.0.0.1',
            ipsecLocalNetworks: ['10.0.0.0/24'],
            ipsecRemoteGateway: '10.0.1.1',
            ipsecRemoteNetworks: ['10.0.1.0/24'],
            ipsecBoundTo: 'eth0',
            ipsecAuthType: 'PSK',
          },
          {
            device: 'eth1',
            description: 'External',
            status: 'connected',
            duplex: 'Full-duplex',
            mac: '66:77:88:99:AA:BB',
            mtu: 1500,
            speed: '1 Gbit',
            type: 'NIC',
            originalType: 'NIC',
            download: '0 Mbps',
            upload: '0 Mbps',
            ipv4Address: '192.168.58.109',
            ipv4Gateway: '',
            ipv6Address: 'N/A',
            ipv6Gateway: '',
            dnsServers: [],
            bridgedTo: '-',
            parentBridge: '-',
            ipsecLocalGateway: '',
            ipsecLocalNetworks: [],
            ipsecRemoteGateway: '',
            ipsecRemoteNetworks: [],
            ipsecBoundTo: '',
            ipsecAuthType: '',
          },
        ]
      },

      // rowData() {
      //   return this.interfaces?.map(intf => {
      //     const status = this.interfacesStatusMap?.[intf.device]

      //     return {
      //       device: intf.device,
      //       description: intf.name,
      //       status: this.getStatus(intf, status),
      //       duplex: this.getDuplex(intf, status),
      //       mac: this.getMac(intf, status),
      //       mtu: intf.mtu,
      //       speed: this.getSpeed(intf, status),
      //       type: this.getType(intf),
      //       originalType: intf.type,
      //       download: this.getDownload(intf, status),
      //       upload: this.getUpload(intf, status),
      //       ipv4Address: this.getIpv4Address(intf, status),
      //       ipv4Gateway: this.getIpv4Gateway(intf, status),
      //       ipv6Address: this.getIpv6Address(intf, status),
      //       ipv6Gateway: this.getIpv6Gateway(intf, status),
      //       dnsServers: this.getDnsServers(intf, status),
      //       bridgedTo: this.getBridgedTo(intf),
      //       parentBridge: this.getParentBridge(intf),
      //       ipsecLocalGateway: this.getIpsecLocalGateway(intf),
      //       ipsecLocalNetworks: this.getIpsecLocalNetworks(intf),
      //       ipsecRemoteGateway: this.getIpsecRemoteGateway(intf),
      //       ipsecRemoteNetworks: this.getIpsecRemoteNetworks(intf),
      //       ipsecBoundTo: this.getIpsecBoundTo(intf),
      //       ipsecAuthType: this.getIpsecAuthType(intf),
      //     }
      //   })
      // },

      /**
       * Returns a map of interfaces status based on interface device
       * @param {Object} vm - vue instance
       * @param {Object} vm.interfacesStatus - all interfaces status
       * @returns {Object} - the status mapped by interface device
       */
      // interfacesStatusMap: ({ interfacesStatus }) => {
      //   if (!interfacesStatus) return
      //   const map = {}
      //   interfacesStatus?.forEach(intfStat => {
      //     map[intfStat.device] = intfStat
      //   })
      //   return map
      // },

      /**
       * Returns menu items based on features
       * @param {Object} vm - vue instance
       * @param {Object} vm.features - the features to be applied to the component
       * @param {Object} vm.$i18n - translation engine
       * @returns {Array} - available menu items
       */
      // menuItems: ({ features, $i18n }) => {
      //   return [
      //     ...(features.hasOpenVpn ? [{ text: $i18n.t('open_vpn'), to: 'openvpn' }] : []),
      //     ...(features.hasWireguard ? [{ text: $i18n.t('wireguard'), to: 'wireguard' }] : []),
      //     { text: $i18n.t('vlan'), to: 'vlan' },
      //     { text: $i18n.t('ipsec_tunnel'), to: 'ipsec' },
      //     ...(features.hasBridged ? [{ text: $i18n.t('bridge'), to: 'bridge' }] : []),
      //   ]
      // },
    },

    methods: {
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
