<template>
  <u-widget :title="$t('network_layout')" :enable-expand="false" enable-refresh @refresh="loadData">
    <u-network-layout :fetching="fetching" :wan-interfaces="wanInterfaces" :lan-interfaces="lanInterfaces" />
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

        const [, statusList, metricsResponse] = await Promise.all([
          this.$store.dispatch('config/getNetworkSettings', true),
          rpcCall(window.rpc?.networkManager?.getAllInterfacesStatusV2, [], { fallback: [] }),
          rpcCall(window.rpc?.metricManager?.getMetricsAndStatsV2, [], { fallback: null }),
        ])

        const interfaces = this.$store.state.config.networkSetting?.interfaces || []
        const systemStats = metricsResponse?.systemStats || {}

        const statusMap = (Array.isArray(statusList) ? statusList : []).reduce((map, s) => {
          if (s?.interfaceId) map[s.interfaceId] = s
          return map
        }, {})

        this.wanInterfaces = []
        this.lanInterfaces = []

        interfaces.forEach(iface => {
          if (iface.configType === 'DISABLED') return
          const id = iface.interfaceId
          const merged = Object.assign({}, iface, statusMap[id], {
            rxByteRate: systemStats[`interface_${id}_rxBps`] || 0,
            txByteRate: systemStats[`interface_${id}_txBps`] || 0,
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
