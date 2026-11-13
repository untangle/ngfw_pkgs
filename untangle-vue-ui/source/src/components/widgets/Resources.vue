<template>
  <u-widget :title="$t('resources')" :enable-expand="false">
    <div class="d-flex flex-row justify-space-around ma-8">
      <div v-for="(res, key) in resources" :key="key" class="text-center">
        {{ $t(res.name) }} <br />
        <strong>{{ res.total }}</strong>
        <br />
        <v-progress-circular
          :rotate="-90"
          :size="100"
          :width="10"
          :value="res.percent || 0"
          :color="computeColor(res.percent, key === 'disk')"
          class="mt-4"
        >
          <span class="text-center text-h5 font-weight-light" v-text="res.percent + '%'" />
        </v-progress-circular>
      </div>
    </div>
  </u-widget>
</template>

<script>
  import widgetsMixin from './widgetsMixin'
  import util from '@/util/util'

  export default {
    mixins: [widgetsMixin],

    data: () => ({
      systemStats: {},
    }),

    computed: {
      resources() {
        const s = this.systemStats
        return {
          memory: {
            name: 'memory',
            total: this.formatTotal(s.MemTotal),
            percent: this.computePercent(s.MemTotal, s.MemFree),
          },
          ...(s.SwapTotal > 0 && {
            swap: {
              name: 'swap',
              total: this.formatTotal(s.SwapTotal),
              percent: this.computePercent(s.SwapTotal, s.SwapFree),
            },
          }),
          disk: {
            name: 'disk',
            total: this.formatTotal(s.totalDiskSpace),
            percent: this.computePercent(s.totalDiskSpace, s.freeDiskSpace),
          },
        }
      },
    },

    methods: {
      loadData() {
        this.systemStats = this.$store.state.config.metricsAndStats?.systemStats || {}
      },

      formatTotal: total => (total > 0 ? util.formatBytes(total) : null),

      computePercent(total, free) {
        return total > 0 && free >= 0 ? Math.round((1 - free / total) * 100) : null
      },

      computeColor(percent, isDisk = false) {
        if (isDisk && percent != null && percent > 95) return 'red'
        if (percent != null && percent > 50) return 'orange'
        return 'aristaMediumBlue'
      },
    },
  }
</script>
