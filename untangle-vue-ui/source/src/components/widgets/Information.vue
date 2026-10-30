<template>
  <u-widget :title="$t('information')" :enable-expand="false">
    <div class="server-info-container">
      <div class="info-host">
        <div class="hostname">{{ hostname }}</div>
        <div class="version">{{ $t('version') }}: {{ version }}</div>
      </div>
      <table class="server-info">
        <tbody>
          <tr v-for="row in infoRows" :key="row.label">
            <td>{{ row.label }}:</td>
            <td>{{ row.value }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </u-widget>
</template>
<script>
  import widgetsMixin from './widgetsMixin'
  import { rpcCall } from '@/util/rpcHelpers'
  import util from '@/util/util'
  export default {
    mixins: [widgetsMixin],
    data: () => ({
      stats: {},
      uptime: '',
    }),

    computed: {
      uptimeText() {
        return util.formatUptime(this.uptime)
      },
      serverName() {
        const applianceModel = window.rpc?.applianceModel
        return applianceModel === undefined || applianceModel === null || applianceModel === ''
          ? this.$t('custom')
          : applianceModel
      },
      hostname() {
        return window.rpc?.hostname || ''
      },
      version() {
        return window.rpc?.fullVersion || ''
      },
      infoRows() {
        return [
          { label: this.$t('uptime'), value: this.uptimeText },
          { label: this.$t('server'), value: this.serverName },
          { label: this.$t('cpu_count'), value: this.cpuCount },
          { label: this.$t('cpu_type'), value: this.cpuType },
          { label: this.$t('architecture'), value: this.architecture },
          { label: this.$t('memory'), value: this.memoryText },
          { label: this.$t('disk'), value: this.diskText },
        ]
      },
      cpuCount() {
        return this.stats.numCpus ?? ''
      },
      cpuType() {
        return this.stats.cpuModel ?? ''
      },
      architecture() {
        return this.stats.architecture ?? ''
      },
      memoryText() {
        return util.formatBytes(this.stats.MemTotal)
      },
      diskText() {
        return util.formatBytes(this.stats.totalDiskSpace)
      },
    },

    methods: {
      async loadData() {
        const response = await rpcCall(window.rpc?.metricManager?.getMetricsAndStatsV2, [], { fallback: null })
        this.stats = response?.systemStats || {}
        const uptime = Number(this.stats.uptime)
        this.uptime = Number.isFinite(uptime) ? Math.floor(uptime) : ''
      },
    },
  }
</script>
<style lang="scss" scoped>
  .server-info-container {
    width: 100%;
    margin: auto;
  }
  .info-host {
    padding: 8px 5px 7px;
    text-align: center;
    background: #f0f0f0;
    .hostname {
      font-size: 18px;
      font-weight: bold;
      line-height: 16px;
    }
    .version {
      margin-top: 3px;
      font-size: 11px;
      font-weight: bold;
      line-height: 12px;
    }
  }
  .server-info {
    width: 100%;
    margin-top: 10px;
    border-spacing: 0 2px;
    tr {
      td {
        font-size: 14px;
        &:nth-child(1) {
          width: 45%;
          text-align: right;
          padding-right: 8px;
        }
        &:nth-child(2) {
          width: 55%;
          font-weight: bold;
        }
      }
    }
  }
</style>
