<template>
  <settings-dynamic-routes
    ref="dynamicRoutes"
    :network-settings="networkSettings"
    :settings="dynamicRoutingSettings"
    :status-table-data="statusTableData"
    @refresh="onRefresh"
    @fetch-routing-table-status="fetchRoutingTableStatus"
  >
    <template #actions="{ newSettings, isDirty, validate }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSave(newSettings, validate)">{{ $t('save') }}</u-btn>
    </template>
  </settings-dynamic-routes>
</template>
<script>
  import { cloneDeep } from 'lodash'
  import { SettingsDynamicRoutes } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import Rpc from '@/util/Rpc'
  import Util from '@/util/setupUtil'

  export default {
    components: { SettingsDynamicRoutes },
    mixins: [settingsMixin],

    data() {
      return {
        warningsMessages: [],
        warningsCount: 0,
        statusTableData: [],
      }
    },

    computed: {
      networkSettings: ({ $store }) => $store.getters['settings/networkSetting'],
      dynamicRoutingSettings: ({ $store }) => $store.getters['settings/dynamicRoutingSettings'],
    },

    created() {
      this.fetchNetworkSettings(false)
    },

    methods: {
      async fetchNetworkSettings(refetch) {
        await this.$store.dispatch('settings/getNetworkSettings', refetch)
      },

      /**
       * The fetchRoutingTableStatus function is triggered every time the screen is displayed.
       * To refresh the current routes, we use the same function.
       */
      async fetchRoutingTableStatus(cb) {
        try {
          const response = await Rpc.asyncData('rpc.networkManager.getStatus', 'ROUTING_TABLE', null)
          // Call the callback if provided
          if (cb) cb(response ?? null)
          // Return the response for awaiting
          return response ?? null
        } catch (err) {
          Util.handleException(err)
          if (cb) cb(null)
          return null
        }
      },

      /** fetch Dynamic Routing Status */
      async onRefresh() {
        try {
          this.$store.commit('SET_LOADER', true)

          const [tableStatus, bgpStatus, ospfStatus] = await Promise.all([
            Rpc.asyncData('rpc.networkManager.getStatus', 'DYNAMIC_ROUTING_TABLE', null),
            Rpc.asyncData('rpc.networkManager.getStatus', 'DYNAMIC_ROUTING_BGP', null),
            Rpc.asyncData('rpc.networkManager.getStatus', 'DYNAMIC_ROUTING_OSPF', null),
          ])

          // ---- Build Dynamic Routes ----
          const routeStore = []
          let currentNetwork = null
          let firstNexthop = false
          tableStatus?.split('\n').forEach(line => {
            line = line.trim()
            if (!line || line.includes('Exiting:')) return

            const columns = line?.split(' ')
            let row = {}

            if (columns[0] === 'nexthop') {
              row = currentNetwork ? { ...currentNetwork } : {}
              columns.shift()
              if (!firstNexthop) {
                routeStore.pop()
              }
              firstNexthop = true
            } else {
              const [network, prefix] = columns.shift()?.split('/')
              currentNetwork = { network, prefix, attributes: [] }
              firstNexthop = false
              row = currentNetwork
            }

            for (let i = 0; i < columns.length; i += 2) {
              const columnName = columns[i]
              const columnValue = columns[i + 1]

              if (columnName === 'dev') {
                // lookup interface mapping from Vuex store
                const interfaceRecord = this.networkSettings.interfaces.find(iface => iface.symbolicDev === columnValue)
                row.interface = interfaceRecord ? interfaceRecord.interfaceId : columnValue
              }

              if (['dev', 'metric', 'gw', 'proto'].includes(columnName)) {
                row[columnName] = columnValue
              } else {
                if (!row.attributes) row.attributes = []
                row.attributes.push({ name: columnName, value: columnValue })
              }
            }

            routeStore.push(row)
          })
          this.dynamicRoutesStatus = routeStore

          // ---- Build BGP Neighbor Status ----
          const bgpStore = []
          bgpStatus?.split('\n').forEach(line => {
            line = line.trim()
            if (!line || line.includes('Exiting:') || line.includes('bgpd is not running')) return

            const columns = line?.split(' ')
            let uptime = 0
            if (columns[8] !== 'never') {
              let uptimes = columns[8].trim()?.split(/[dhm]/)
              if (uptimes.length > 1) {
                uptime =
                  parseInt(uptimes[0], 10) * 86400 + parseInt(uptimes[1], 10) * 3600 + parseInt(uptimes[2], 10) * 60
              } else {
                uptimes = columns[8]?.split(':')
                uptime =
                  parseInt(uptimes[uptimes.length - 1], 10) +
                  parseInt(uptimes[uptimes.length - 2], 10) * 60 +
                  parseInt(uptimes[uptimes.length - 3], 10) * 3600
              }
              uptime *= 1000
            }
            bgpStore.push({
              neighbor: columns[0],
              as: columns[2],
              msgsRecv: columns[3],
              msgsSent: columns[4],
              uptime,
            })
          })
          this.bgpStatus = bgpStore
          // ---- Build OSPF Status ----
          const ospfStore = []
          ospfStatus?.split('\n').forEach(line => {
            line = line.trim()
            if (!line || line.includes('Exiting:') || line.includes('ospfd is not running')) return
            const columns = line?.split(' ')
            const dev = columns[5]?.split(':')[0]
            const interfaceRecord = this.networkSettings.interfaces.find(iface => iface.symbolicDev === dev)
            const interfaceId = interfaceRecord ? interfaceRecord.interfaceId : dev
            ospfStore.push({
              neighbor: columns[0],
              address: columns[4],
              time: parseFloat(columns[3]),
              dev,
              interface: interfaceId,
            })
          })
          this.ospfStatus = ospfStore
          this.statusTableData = [
            { dynamicRoutesStatus: this.dynamicRoutesStatus },
            { bgpStatus: this.bgpStatus },
            { ospfStatus: this.ospfStatus },
          ]
        } catch (ex) {
          Util.handleException(ex)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      async onSave(updatedSettings, validate) {
        const isValid = await validate()
        if (!isValid) return
        this.$store.commit('SET_LOADER', true)
        const networkdynamicRoutingSettings = cloneDeep(this.networkSettings)
        networkdynamicRoutingSettings.dynamicRoutingSettings = updatedSettings
        await Promise.all([
          this.$store.dispatch('settings/setNetworkSettingV2', networkdynamicRoutingSettings),
        ]).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
      },

      /**
       * Optional hook triggered on browser refresh.
       * Fetches updated settings.
       * Fetches updated status
       */
      onBrowserRefresh() {
        this.fetchNetworkSettings(true)
      },
    },
  }
</script>
