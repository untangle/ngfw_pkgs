<template>
  <u-widget :title="$t('network_layout')" :enable-expand="false" enable-refresh @refresh="loadData">
    <u-network-layout
      class="dashboard-network-layout"
      :fetching="fetching"
      :wan-interfaces="wanInterfaces"
      :lan-interfaces="lanInterfaces"
      :format-rate="formatRate"
      :show-vrrp-label="showVrrpLabel"
    />
  </u-widget>
</template>

<script>
  import widgetsMixin from './widgetsMixin'
  import { directRpcCall, rpcCall } from '@/util/rpcHelpers'

  export default {
    mixins: [widgetsMixin],

    data: () => ({
      fetching: true,
      wanInterfaces: [],
      lanInterfaces: [],
    }),

    methods: {
      async loadData() {
        this.fetching = true

        try {
          const [, statusResponse, metricsResponse, hostsResponse] = await Promise.all([
            this.$store.dispatch('config/getNetworkSettings', true),
            rpcCall(window.rpc?.networkManager?.getAllInterfacesStatusV2, [], { fallback: [] }),
            rpcCall(window.rpc?.metricManager?.getMetricsAndStatsV2, [], { fallback: null }),
            rpcCall(window.rpc?.hostTable?.getHosts, [], { fallback: null }),
          ])

          const networkSettings = this.$store.state.config.networkSetting || {}
          const interfaces = this.toList(networkSettings.interfaces)
          const statusList = this.toList(statusResponse)
          const hostList = this.toList(hostsResponse)
          const systemStats = metricsResponse?.systemStats || {}

          const statusMap = statusList.reduce((map, status) => {
            if (status?.interfaceId != null) map[status.interfaceId] = status
            return map
          }, {})

          const deviceCountMap = hostList.reduce((map, host) => {
            if (host?.active && host?.interfaceId != null) {
              map[host.interfaceId] = (map[host.interfaceId] || 0) + 1
            }
            return map
          }, {})

          // The V2 settings API represents disabled interfaces with enabled=false.
          // Keep the legacy configType check as a safe compatibility guard.
          const activeInterfaces = interfaces.filter(
            iface => iface && iface.enabled !== false && iface.configType !== 'DISABLED',
          )

          this.wanInterfaces = []
          this.lanInterfaces = []

          activeInterfaces.forEach(iface => {
            const id = iface.interfaceId
            const vrrpEnabled = this.isTrue(iface.vrrpEnabled)
            const vrrpMaster = vrrpEnabled
              ? this.isTrue(
                  directRpcCall(window.rpc?.networkManager?.isVrrpMaster, [id], {
                    mode: 'ignore',
                    fallback: false,
                  }),
                )
              : false
            const merged = Object.assign({}, iface, statusMap[id], {
              rxByteRate: this.getRate(systemStats, id, 'rx'),
              txByteRate: this.getRate(systemStats, id, 'tx'),
              vrrpEnabled,
              vrrpMaster,
              devicesCount: deviceCountMap[id] || 0,
            })

            if (this.isTrue(iface.wan)) {
              this.wanInterfaces.push(merged)
            } else {
              this.lanInterfaces.push(merged)
            }
          })
        } finally {
          this.fetching = false
        }
      },

      toList(value) {
        if (Array.isArray(value)) return value
        return Array.isArray(value?.list) ? value.list : []
      },

      isTrue(value) {
        return value === true || value === 'true'
      },

      getRate(systemStats, interfaceId, direction) {
        const value = Number(systemStats[`interface_${interfaceId}_${direction}Bps`])
        return Number.isFinite(value) ? value : 0
      },

      formatRate(bps) {
        if (!bps) return '0 bytes/s'
        if (bps < 1000) return `${parseFloat(bps.toFixed(2))} bytes/s`
        if (bps < 1000000) return `${parseFloat((bps / 1000).toFixed(2))} Kbytes/s`
        return `${parseFloat((bps / 1000000).toFixed(2))} Mbytes/s`
      },

      showVrrpLabel(networkInterface) {
        return this.isTrue(networkInterface?.vrrpEnabled) && this.isTrue(networkInterface?.vrrpMaster)
      },
    },
  }
</script>
<style lang="scss">
  .dashboard-network-layout .vrrp-label {
    display: inline-block;
    font-family: tahoma, arial, verdana, sans-serif;
    font-size: 8px;
    line-height: normal;
    color: #fff !important;
    background-color: #6d6d6d !important;
    padding: 0 3px;
    margin-left: 5px;
    border-radius: 3px;
    vertical-align: super;
    position: relative;
    z-index: 1;
  }
</style>
