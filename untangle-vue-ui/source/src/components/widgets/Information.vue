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
  import Rpc from '@/util/Rpc'

  export default {
    mixins: [widgetsMixin],
    data: () => ({
      stats: {},
      uptime: '',
    }),
    computed: {
      uptimeText() {
        return formatUptime(this.uptime)
      },
      serverName() {
        return this.stats.appliance || window.rpc?.applianceModel || 'custom'
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
          { label: 'CPU Count', value: this.cpuCount },
          { label: 'CPU Type', value: this.cpuType },
          { label: 'Architecture', value: this.architecture },
          { label: this.$t('memory'), value: this.memoryText },
          { label: 'Disk', value: this.diskText },
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
        return formatBytes(this.stats.MemTotal)
      },
      diskText() {
        return formatBytes(this.stats.totalDiskSpace)
      },
    },
    methods: {
      async loadData() {
        try {
          const response = await Rpc.asyncData('rpc.metricManager.getMetricsAndStatsV2')
          this.stats = response?.systemStats || {}
        } catch {
          this.stats = {}
        }
        const uptime = Number(this.stats.uptime)
        this.uptime = Number.isFinite(uptime) ? Math.floor(uptime) : ''
      },
    },
  }

  function formatBytes(value) {
    if (value === null || value === undefined || value === '') {
      return ''
    }

    const bytes = Number(value)
    if (!Number.isFinite(bytes)) {
      return ''
    }
    if (bytes === 0) {
      return '0'
    }

    const units = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']
    const index =
      Math.abs(bytes) < 1000 ? 0 : Math.min(Math.floor(Math.log(Math.abs(bytes)) / Math.log(1000)), units.length - 1)
    return `${parseFloat((bytes / 1000 ** index).toFixed(2))} ${units[index]}`
  }

  function formatUptime(value) {
    if (value === '' || value === null || value === undefined) {
      return ''
    }

    const seconds = Number(value)
    if (!Number.isFinite(seconds) || seconds < 0) {
      return ''
    }

    const years = Math.floor(seconds / 31536000)
    const days = Math.floor((seconds % 31536000) / 86400)
    const hours = Math.floor((seconds % 86400) / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)

    return [
      years > 0 ? `${years}y` : '',
      days > 0 ? `${days}d` : '',
      hours > 0 ? `${hours}h` : '',
      minutes > 0 ? `${minutes}m` : '',
    ]
      .filter(Boolean)
      .join(' ')
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
