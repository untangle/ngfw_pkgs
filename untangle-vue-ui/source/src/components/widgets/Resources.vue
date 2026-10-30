<template>
  <u-widget :title="$t('resources')" :enable-expand="false">
    <div class="resources-wrapper">
      <div class="resource-legend"><span class="legend-dot used" />Used <span class="legend-dot free" />Free</div>
      <div class="flex-grow-1" style="position: relative">
        <u-chart-stock :fetching="fetching" :options="chartOptions" />
      </div>
    </div>
  </u-widget>
</template>

<script>
  import widgetsMixin from './widgetsMixin'
  import { rpcCall } from '@/util/rpcHelpers'
  import util from '@/util/util'

  const FREE_COLOR = '#90ed7d'
  const USED_COLOR = '#7cb5ec'
  const DISK_CRITICAL_COLOR = '#f44336'

  function buildSeries(name, totalBytes, usedPercent, usedColor, usedBytes, freeBytes) {
    const freePercent = parseFloat((100 - usedPercent).toFixed(1))
    return {
      type: 'pie',
      name,
      totalBytes,
      size: 120,
      data: [
        { name: 'Used', y: usedPercent, color: usedColor, bytes: usedBytes },
        { name: 'Free', y: freePercent, color: FREE_COLOR, bytes: freeBytes },
      ],
    }
  }

  const X_CENTERS = {
    1: ['50%'],
    2: ['25%', '75%'],
    3: ['17%', '50%', '83%'],
  }

  export default {
    mixins: [widgetsMixin],

    data: () => ({
      fetching: true,
      chartOptions: {
        chart: {
          type: 'pie',
          height: 230,
          margin: [5, 5, 60, 5],
          backgroundColor: 'transparent',
          animation: false,
          events: {
            render() {
              const chart = this
              if (chart._resourceLabels) {
                chart._resourceLabels.forEach(el => el.destroy())
              }
              chart._resourceLabels = []
              chart.series.forEach(series => {
                if (!series.center) return
                const cx = chart.plotLeft + series.center[0]
                const labelY = chart.plotTop + series.center[1] + series.center[2] / 2 + 32
                chart._resourceLabels.push(
                  chart.renderer
                    .text(series.name, cx, labelY)
                    .css({ fontSize: '13px', fontWeight: 'bold', color: '#555' })
                    .attr({ align: 'center' })
                    .add(),
                )
                chart._resourceLabels.push(
                  chart.renderer
                    .text(series.options.totalBytes || '', cx, labelY + 16)
                    .css({ fontSize: '12px', color: '#333' })
                    .attr({ align: 'center' })
                    .add(),
                )
              })
            },
          },
        },
        navigator: { enabled: false },
        rangeSelector: { enabled: false },
        scrollbar: { enabled: false },
        title: { text: null },
        credits: { enabled: false },
        legend: { enabled: false },
        tooltip: {
          useHTML: true,
          // eslint-disable-next-line object-shorthand
          formatter: function () {
            return `<b>${this.point.name}:</b> ${this.point.bytes} (${this.point.percentage.toFixed(1)}%)`
          },
        },
        plotOptions: {
          pie: {
            dataLabels: { enabled: false },
            borderWidth: 0,
          },
        },
        series: [],
      },
    }),

    methods: {
      async loadData() {
        this.fetching = true
        const response = await rpcCall(window.rpc?.metricManager?.getMetricsAndStatsV2, [], { fallback: null })
        const { MemFree, MemTotal, SwapFree, SwapTotal, freeDiskSpace, totalDiskSpace } = response?.systemStats || {}
        const series = []

        if (MemTotal) {
          const usedPercent = parseFloat(((1 - MemFree / MemTotal) * 100).toFixed(1))
          series.push(
            buildSeries(
              this.$t('memory'),
              util.formatBytes(MemTotal),
              usedPercent,
              USED_COLOR,
              util.formatBytes(MemTotal - MemFree),
              util.formatBytes(MemFree),
            ),
          )
        }

        if (SwapTotal) {
          const usedPercent = parseFloat(((1 - SwapFree / SwapTotal) * 100).toFixed(1))
          series.push(
            buildSeries(
              'Swap',
              util.formatBytes(SwapTotal),
              usedPercent,
              USED_COLOR,
              util.formatBytes(SwapTotal - SwapFree),
              util.formatBytes(SwapFree),
            ),
          )
        }

        if (totalDiskSpace) {
          const freePercent = parseFloat(((freeDiskSpace / totalDiskSpace) * 100).toFixed(1))
          const usedPercent = parseFloat((100 - freePercent).toFixed(1))
          const diskColor = freePercent < 5 ? DISK_CRITICAL_COLOR : USED_COLOR
          series.push(
            buildSeries(
              this.$t('disk'),
              util.formatBytes(totalDiskSpace),
              usedPercent,
              diskColor,
              util.formatBytes(totalDiskSpace - freeDiskSpace),
              util.formatBytes(freeDiskSpace),
            ),
          )
        }

        const xCenters = X_CENTERS[series.length] || X_CENTERS[3]
        series.forEach((s, i) => {
          s.center = [xCenters[i], '50%']
        })

        this.$set(this.chartOptions, 'series', series)
        this.fetching = false
      },
    },
  }
</script>

<style lang="scss" scoped>
  .resources-wrapper {
    display: flex;
    flex-direction: column;
    height: 100%;
  }

  .resource-legend {
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 11px;
    color: #555;
    align-self: flex-end;
    padding: 4px 8px 0;
  }

  .legend-dot {
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    margin-right: 4px;

    &.used {
      background: #7cb5ec;
    }

    &.free {
      background: #90ed7d;
    }
  }
</style>
