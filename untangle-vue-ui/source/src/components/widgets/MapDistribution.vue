<template>
  <u-widget :title="$t('map_distribution')" enable-expand :fetching="fetching" enable-refresh @refresh="loadData">
    <u-chart ref="hc" constructor-type="mapChart" :options="options" class="map" v-on="$listeners" />
  </u-widget>
</template>

<script>
  import Highcharts from 'highcharts'
  import mapInit from 'highcharts/modules/map'
  import worldMap from '@highcharts/map-collection/custom/world.geo.json'
  import widgetsMixin from './widgetsMixin'
  import { rpcCall } from '@/util/rpcHelpers'
  import util from '@/util/util'

  if (typeof Highcharts.mapChart !== 'function') {
    mapInit(Highcharts)
  }
  Highcharts.maps.worldMap = worldMap

  function bytesToDynamicSize(bytes) {
    if (bytes < 1000) return 10
    if (bytes < 1000 * 1000) return 30
    if (bytes < 1000 * 1000 * 1000) return 50
    if (bytes < 1000 * 1000 * 1000 * 1000) return 70
    return 90
  }

  export default {
    mixins: [widgetsMixin],

    data: () => ({
      fetching: false,
      bubbleData: [],
    }),

    computed: {
      options() {
        return {
          chart: {
            map: 'worldMap',
            margin: [5, 5, 5, 5],
            spacing: [5, 5, 5, 5],
            backgroundColor: this.$vuntangle.theme === 'dark' ? '#1E1E1E' : '#FFFFFF',
            animation: false,
          },
          title: { text: null },
          legend: { enabled: false },
          credits: { enabled: false },
          exporting: { enabled: false },
          mapNavigation: {
            enabled: true,
            enableMouseWheelZoom: true,
            buttonOptions: {
              verticalAlign: 'bottom',
              x: 5,
            },
          },
          plotOptions: {
            series: {
              allowPointSelect: true,
              point: {
                events: {
                  click: event => {
                    const country = event.point.country
                    if (!country) return
                    const href = window.parent.location.href
                    const base = href.replace(/#.*/, '')
                    window.parent.location.href = `${base}#sessions/?serverCountry=${country}`
                  },
                },
              },
            },
          },
          tooltip: {
            headerFormat: '',
            useHTML: true,
            hideDelay: 0,
            pointFormatter() {
              let str = `<strong>${this.country}</strong><br/><strong>${this.sessionCount}</strong> sessions<br/>`
              if (this.numberPart) str += `<strong>${this.numberPart}</strong> ${this.unitPart}`
              return str
            },
          },
          series: [
            {
              name: 'Countries',
              color: '#E0E0E0',
              enableMouseTracking: false,
            },
            {
              type: 'mapbubble',
              joinBy: ['iso-a2', 'country'],
              minSize: 10,
              maxSize: 50,
              zMax: 500,
              data: this.bubbleData,
            },
          ],
        }
      },
    },

    mounted() {
      this.$nextTick(() => {
        setTimeout(() => {
          this.$refs.hc?.$refs?.hc?.chart?.reflow()
        }, 100)
      })
    },

    beforeDestroy() {
      const chart = this.$refs.hc?.$refs?.hc?.chart
      if (chart) chart.destroy()
    },

    methods: {
      async loadData() {
        this.fetching = true
        const result = await rpcCall(window.rpc?.UvmContext?.geographyManager?.()?.getGeoSessionStats, [], {
          fallback: [],
          mode: 'ignore',
        })
        this.fetching = false

        this.bubbleData = (result || []).map(item => {
          let z = 0
          let numberPart = 0
          let unitPart = ''
          if (item.bps) {
            const formatted = util.formatBytes(item.bps)
            const match = formatted.match(/([\d.]+)\s*(.*)/)
            if (match) {
              numberPart = parseFloat(match[1])
              unitPart = match[2]
            }
            z = bytesToDynamicSize(item.bps)
          }
          return {
            country: item.country,
            z,
            numberPart,
            unitPart,
            sessionCount: item.sessionCount,
          }
        })
      },
    },
  }
</script>

<style scoped>
  .map {
    width: 100%;
    height: 100%;
  }
</style>
