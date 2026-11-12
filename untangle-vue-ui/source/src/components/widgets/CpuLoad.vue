<template>
  <u-widget :title="$t('cpu_load')" :enable-expand="false">
    <div class="cpu-load-wrapper">
      <div class="current-load" :style="{ color: displayLoadColor }">
        {{ typeof displayLoad === 'number' ? displayLoad.toFixed(2) : '' }}
      </div>
      <div class="load-label">{{ loadLabel }}</div>
      <div class="flex-grow-1" style="position: relative">
        <u-chart :fetching="fetching" :options="options" />
      </div>
    </div>
  </u-widget>
</template>
<script>
  import widgetsMixin from './widgetsMixin'

  export default {
    mixins: [widgetsMixin],

    data() {
      return {
        fetching: true,
        currentLoad: null,
        displayLoad: null,
        displayLoadColor: this.$vuetify.theme.currentTheme.utGreen,
        numCpus: 1,
        options: {
          time: { useUTC: true },
          chart: {
            marginLeft: 0,
            marginRight: 0,
            spacingBottom: 8,
            marginTop: 12,
            type: 'areaspline',
            animation: false,
            backgroundColor: 'transparent',
          },
          title: { text: null },
          credits: { enabled: false },
          exporting: { enabled: false },
          legend: { enabled: false },
          tooltip: { enabled: false },
          xAxis: {
            type: 'datetime',
            crosshair: { width: 1, dashStyle: 'ShortDot', color: 'rgba(100, 100, 100, 0.3)' },
            lineColor: '#C0D0E0',
            lineWidth: 1,
            tickLength: 3,
            gridLineWidth: 1,
            gridLineDashStyle: 'dash',
            gridLineColor: '#EEE',
            labels: { style: { color: '#999', fontSize: '11px', fontWeight: 600 }, y: 12 },
            maxPadding: 0,
            minPadding: 0,
          },
          yAxis: {
            min: 0,
            minRange: 2,
            lineColor: '#C0D0E0',
            lineWidth: 1,
            gridLineWidth: 1,
            gridLineDashStyle: 'dash',
            gridLineColor: '#EEE',
            tickAmount: 4,
            tickLength: 5,
            tickWidth: 1,
            tickPosition: 'inside',
            opposite: false,
            title: null,
            labels: {
              align: 'left',
              useHTML: true,
              padding: 0,
              style: {
                color: '#999',
                fontSize: '11px',
                fontWeight: 600,
                background: 'rgba(255, 255, 255, 0.6)',
                padding: '0 1px',
                borderRadius: '2px',
                lineHeight: '11px',
              },
              x: 1,
              y: -2,
            },
          },
          plotOptions: {
            areaspline: {
              lineWidth: 1,
              marker: { enabled: false, radius: 1 },
              states: { hover: { enabled: true, lineWidthPlus: 0, marker: { radius: 1 } } },
              color: '#519839',
              fillColor: {
                linearGradient: { x1: 0, y1: 0, x2: 0, y2: 1 },
                stops: [
                  [0, 'rgba(81, 152, 57, 0.5)'],
                  [1, 'rgba(81, 152, 57, 0.2)'],
                ],
              },
            },
            series: {
              point: {
                events: {
                  mouseOver: ({ target }) => {
                    this.displayLoad = target.y
                    this.displayLoadColor = '#999999'
                  },
                },
              },
              events: {
                mouseOut: this.showCurrentLoad,
              },
            },
          },
          series: [
            {
              name: 'load',
              data: (() => {
                const data = []
                const time = Math.round(Date.now() / 1000) * 1000
                for (let i = -6; i <= 0; i += 1) {
                  data.push({ x: time + i * 10000, y: 0 })
                }
                return data
              })(),
            },
          ],
        },
      }
    },

    computed: {
      medLimit() {
        return this.numCpus + 1
      },
      highLimit() {
        return this.numCpus + 4
      },
      loadLabel() {
        let label = ''
        if (this.currentLoad < this.medLimit) label = this.$t('low')
        if (this.currentLoad > this.medLimit) label = this.$t('medium')
        if (this.currentLoad > this.highLimit) label = this.$t('high')
        return label
      },
    },

    methods: {
      loadData() {
        this.fetching = true
        const stats = this.$store.state.config.metricsAndStats?.systemStats || {}
        const load = stats.oneMinuteLoadAvg
        this.numCpus = stats.numCpus || 1
        this.options.yAxis.minRange = this.numCpus
        this.currentLoad = typeof load === 'number' ? load : null
        this.options.series[0].data.push({ x: Date.now(), y: this.currentLoad ?? 0 })
        this.options.series[0].data.shift()
        this.showCurrentLoad()
        this.fetching = false
      },

      showCurrentLoad() {
        this.displayLoad = this.currentLoad
        this.displayLoadColor = this.$vuetify.theme.currentTheme.utGreen
      },
    },
  }
</script>
<style lang="scss" scoped>
  .cpu-load-wrapper {
    display: flex;
    flex-direction: column;
    height: 100%;
  }

  .current-load {
    font-size: 54px;
    font-weight: 400;
    text-align: center;
    min-height: 72px;
  }

  .load-label {
    text-align: center;
    font-size: 13px;
    color: #020202;
    margin-bottom: 4px;
    text-transform: uppercase;
  }
</style>
