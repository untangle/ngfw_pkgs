<template>
  <u-widget :title="$t('network_layout')" :enable-expand="false" enable-refresh @refresh="loadData">
    <u-network-layout
      class="dashboard-network-layout"
      :fetching="fetching"
      :wan-interfaces="wanInterfaces"
      :lan-interfaces="lanInterfaces"
    />
  </u-widget>
</template>

<script>
  import widgetsMixin from './widgetsMixin'
  import { rpcCall } from '@/util/rpcHelpers'

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

        const [, statusList, metricsResponse, hostsResponse] = await Promise.all([
          this.$store.dispatch('config/getNetworkSettings', true),
          rpcCall(window.rpc?.networkManager?.getAllInterfacesStatusV2, [], { fallback: [] }),
          rpcCall(window.rpc?.metricManager?.getMetricsAndStatsV2, [], { fallback: null }),
          rpcCall(window.rpc?.hostTable?.getHosts, [], { fallback: null }),
        ])

        const interfaces = this.$store.state.config.networkSetting?.interfaces || []
        const systemStats = metricsResponse?.systemStats || {}

        const statusMap = (Array.isArray(statusList) ? statusList : []).reduce((map, s) => {
          if (s?.interfaceId) map[s.interfaceId] = s
          return map
        }, {})

        const hostList = hostsResponse?.list || []
        const deviceCountMap = hostList.reduce((map, host) => {
          if (host?.active && host?.interfaceId) {
            map[host.interfaceId] = (map[host.interfaceId] || 0) + 1
          }
          return map
        }, {})

        const activeInterfaces = interfaces.filter(iface => iface.enabled !== false)

        const vrrpMasterMap = {}
        await Promise.all(
          activeInterfaces
            .filter(iface => iface.vrrpEnabled)
            .map(iface =>
              rpcCall(window.rpc?.networkManager?.isVrrpMaster, [iface.interfaceId], { fallback: false }).then(
                result => {
                  vrrpMasterMap[iface.interfaceId] = result
                },
              ),
            ),
        )

        this.wanInterfaces = []
        this.lanInterfaces = []

        activeInterfaces.forEach(iface => {
          const id = iface.interfaceId
          const merged = Object.assign({}, iface, statusMap[id], {
            rxByteRate: systemStats[`interface_${id}_rxBps`] || 0,
            txByteRate: systemStats[`interface_${id}_txBps`] || 0,
            vrrpEnabled: iface.vrrpEnabled,
            vrrpMaster: iface.vrrpEnabled ? Boolean(vrrpMasterMap[id]) : false,
            devicesCount: deviceCountMap[id] || 0,
          })
          if (merged.wan) {
            this.wanInterfaces.push(merged)
          } else {
            this.lanInterfaces.push(merged)
          }
        })

        this.fetching = false
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
