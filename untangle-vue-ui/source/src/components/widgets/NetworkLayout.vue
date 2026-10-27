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
        const response = await rpcCall(window.rpc?.networkManager?.getNetworkSettingsV2, [], { fallback: null })
        const interfaces = response?.interfaces || []

        this.wanInterfaces = []
        this.lanInterfaces = []

        interfaces.forEach(iface => {
          if (iface.configType === 'DISABLED') return
          if (iface.isWan) {
            this.wanInterfaces.push(iface)
          } else {
            this.lanInterfaces.push(iface)
          }
        })

        this.fetching = false
      },
    },
  }
</script>
