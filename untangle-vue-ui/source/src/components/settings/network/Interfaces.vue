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
  export default {
    components: { VContainer, VSpacer, VMenu, VList, VListItem, VListItemTitle, VIcon },
    props: {
      // interfaces settings from box settings.json
      // interfaces: { type: Array, required: true },
      // interfaces status
      interfacesStatus: { type: Array, default: undefined },
      // features that applies to interfaces view
      features: { type: Object, default: undefined },
      // weather the applliance is offline
      disabled: { type: Boolean, default: false },
    },
    data() {
      return {
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
            headerName: $i18n.t('interface'),
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
            headerName: $i18n.t('description'),
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
            headerName: $i18n.t('mac_address'),
            field: 'mac',
          },
          {
            headerName: $i18n.t('mtu'),
            field: 'mtu',
          },
          {
            headerName: $i18n.t('speed'),
            field: 'speed',
          },
          {
            headerName: $i18n.t('type'),
            field: 'type',
          },
          {
            headerName: $i18n.t('ipv4_address'),
            field: 'ipv4Address',
          },
          {
            headerName: $i18n.t('ipv4_gateway'),
            field: 'ipv4Gateway',
            hide: true,
          },
          {
            headerName: $i18n.t('ipv6_address'),
            field: 'ipv6Address',
          },
          {
            headerName: $i18n.t('ipv6_gateway'),
            field: 'ipv6Gateway',
            hide: true,
          },
          {
            headerName: $i18n.t('dns_servers'),
            field: 'dnsServers',
            hide: true,
          },
          {
            headerName: $i18n.t('download'),
            field: 'download',
            hide: true,
          },
          {
            headerName: $i18n.t('upload'),
            field: 'upload',
            hide: true,
          },
          {
            headerName: $i18n.t('bridged_to'),
            field: 'bridgedTo',
            hide: true,
          },
          {
            headerName: $i18n.t('parent_bridge'),
            field: 'parentBridge',
            hide: true,
          },
          // IPsec specific columns
          {
            headerName: `IPsec ${$i18n.t('local_gateway')}`,
            field: 'ipsecLocalGateway',
            hide: true,
          },
          {
            headerName: `IPsec ${$i18n.t('local_networks')}`,
            field: 'ipsecLocalNetworks',
            hide: true,
          },
          {
            headerName: `IPsec ${$i18n.t('remote_gateway')}`,
            field: 'ipsecRemoteGateway',
            hide: true,
          },
          {
            headerName: `IPsec ${$i18n.t('remote_networks')}`,
            field: 'ipsecRemoteNetworks',
            hide: true,
          },
          {
            headerName: `IPsec ${$i18n.t('bound_to')}`,
            field: 'ipsecBoundTo',
            hide: true,
          },
          {
            headerName: `IPsec ${$i18n.t('authentication')}`,
            field: 'ipsecAuthType',
            hide: true,
          },
        ]
      },
      rowData() {
        return null
      },
      /**
       * Returns a map of interfaces status based on interface device
       * @param {Object} vm - vue instance
       * @param {Object} vm.interfacesStatus - all interfaces status
       * @returns {Object} - the status mapped by interface device
       */
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
      console.log('interfaces', this.interfaces)
      this.$store.dispatch('settings/getInterfaces') // make a call for getInterfaces to populate interfaces data from store
    },
    mounted() {
      // console.log('this.rpc11', this.rpc.networkManager.getNetworkSettings())
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
