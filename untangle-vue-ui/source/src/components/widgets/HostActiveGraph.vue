<template>
  <div class="report-graph">
    <u-chart-stock :fetching="fetching" :options="options" />
  </div>
</template>

<script>
  import { UChartStock } from 'vuntangle'

  const DEFAULT_COLORS = ['#7cb5ec', '#434348', '#90ed7d', '#f7a35c', '#8085e9', '#f15c80', '#e4d354']
  const FONT_FAMILY = 'Roboto Condensed, Roboto, sans-serif'

  export default {
    name: 'HostActiveGraph',
    components: { UChartStock },
    props: {
      entry: { type: Object, default: null },
      timeRange: {
        type: Object,
        default: () => ({ period: [Date.now() - 3600000, null] }),
      },
      isWidget: { type: Boolean, default: false },
      refreshTick: { type: Number, default: 0 },
    },
    data() {
      return {
        fetching: false,
        options: createChartOptions([], this.entry, this.timeRange, this.isWidget),
      }
    },
    watch: {
      entry: {
        handler() {
          this.fetchData()
        },
        immediate: true,
      },
      'timeRange.period'() {
        this.fetchData()
      },
      refreshTick(value) {
        if (value > 0) {
          this.fetchData()
        }
      },
    },
    methods: {
      fetchData() {
        if (!this.entry || this.fetching) {
          return
        }

        const [start, end] = this.timeRange.period || []
        const userConditions = [
          {
            column: 'time_stamp',
            operator: 'GT',
            value: start || Date.now() - 3600000,
          },
        ]

        if (end) {
          userConditions.push({ column: 'time_stamp', operator: 'LT', value: end })
        }

        this.fetching = true
        this.$emit('fetch-data', {
          query: {
            key: this.entry.uniqueId,
            userConditions,
          },
          entry: this.entry,
          resolve: data => {
            this.fetching = false
            this.options = createChartOptions(
              Array.isArray(data) ? data : [],
              this.entry,
              this.timeRange,
              this.isWidget,
            )
          },
        })
      },
    },
  }

  function createChartOptions(data = [], entry = {}, timeRange = {}, isWidget = false) {
    const series = getSeries(data, entry)
    const colors = getColors(entry)
    const chartType = getChartType(entry)
    const period = timeRange.period || [Date.now() - 3600000, Date.now()]
    const start = period[0] || Date.now() - 3600000
    const end = period[1] || Date.now()
    const hasPositiveData = series.some(item => item.data.some(point => Number(point[1]) > 0))
    const units = entry.units || ''
    const dataGrouping = {
      approximation: entry.approximation || 'sum',
      dateTimeLabelFormats: getDataGroupingLabelFormats(),
      enabled: true,
      groupPixelWidth: 8,
    }

    return {
      chart: {
        animation: false,
        backgroundColor: 'transparent',
        marginRight: isWidget ? 5 : 20,
        spacing: isWidget ? [5, 5, 10, 5] : [30, 10, 15, 10],
        style: { fontFamily: FONT_FAMILY, fontSize: '10px' },
        type: chartType,
      },
      colors,
      credits: { enabled: false },
      navigator: { enabled: false },
      rangeSelector: { enabled: false },
      scrollbar: { enabled: false },
      xAxis: {
        dateTimeLabelFormats: getXAxisLabelFormats(),
        labels: {
          autoRotation: [-25],
          style: {
            color: '#777',
            fontFamily: FONT_FAMILY,
            fontSize: isWidget ? '11px' : '12px',
            fontWeight: 600,
          },
        },
        lineWidth: 1,
        max: end,
        maxPadding: 0,
        min: start,
        minPadding: 0,
        minRange: 10 * 60 * 1000,
        tickLength: 5,
        tickPixelInterval: isWidget ? 80 : 120,
        type: 'datetime',
      },
      yAxis: {
        allowDecimals: true,
        endOnTick: true,
        ...(hasPositiveData ? {} : { max: 1, tickInterval: 0.25 }),
        gridLineColor: '#EEE',
        gridLineDashStyle: 'Dash',
        gridLineWidth: 1,
        labels: {
          align: 'right',
          padding: 0,
          style: {
            color: '#777',
            fontFamily: FONT_FAMILY,
            fontSize: isWidget ? '11px' : '12px',
            fontWeight: 600,
          },
          formatter() {
            return formatAxisValue(this.value, units)
          },
          x: -10,
          y: 4,
        },
        lineWidth: 1,
        maxPadding: 0,
        min: 0,
        opposite: false,
        showFirstLabel: false,
        showLastLabel: true,
        tickLength: 5,
        tickWidth: 1,
        title: {
          align: 'high',
          offset: -10,
          rotation: 0,
          style: {
            color: '#555',
            fontFamily: FONT_FAMILY,
            fontSize: isWidget ? '12px' : '14px',
            fontWeight: 600,
          },
          text: units,
          textAlign: 'left',
          y: 3,
        },
      },
      tooltip: {
        animation: false,
        backgroundColor: 'rgba(247, 247, 247, 0.95)',
        followPointer: true,
        headerFormat: '<p style="margin: 0 0 5px 0; color: #555;">{point.key}</p>',
        hideDelay: 0,
        padding: 10,
        shared: true,
        split: false,
        style: { fontSize: isWidget ? '12px' : '14px' },
        useHTML: true,
        xDateFormat: '%Y-%m-%d, %H:%M',
        pointFormatter() {
          return `<span style="color: ${this.color}; font-weight: bold;">${this.series.name}</span>: <b>${formatValue(
            this.y,
            units,
          )}</b>${units ? ` ${units}` : ''}<br/>`
        },
      },
      plotOptions: {
        series: {
          animation: true,
          marker: { radius: 2 },
          stacking: entry.timeStyle?.includes('STACKED') ? 'normal' : undefined,
          states: { hover: { lineWidthPlus: 0 } },
        },
        [chartType]: {
          dataGrouping,
          lineWidth: chartType === 'spline' ? 2 : 1,
          ...(chartType === 'column' && {
            borderWidth: entry.timeStyle?.includes('OVERLAPPED') ? 1 : 0,
            grouping: !entry.timeStyle?.includes('OVERLAPPED'),
            groupPadding: entry.timeStyle?.includes('OVERLAPPED') ? 0.1 : 0.15,
            pointPlacement: 'on',
          }),
        },
      },
      legend: {
        enabled: true,
        itemDistance: 10,
        itemStyle: {
          color: '#333',
          fontFamily: FONT_FAMILY,
          fontSize: '12px',
          fontWeight: 600,
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          whiteSpace: 'nowrap',
          width: '120px',
        },
        lineHeight: 12,
        margin: 0,
        symbolHeight: 8,
        symbolRadius: 4,
        symbolWidth: 8,
        y: isWidget ? 5 : 10,
      },
      // Keep configured series when empty so the axes and legend remain visible.
      series: series.map((item, index) => {
        const color = colors[index % colors.length]
        return {
          ...item,
          color,
          fillColor: {
            linearGradient: { x1: 0, y1: 0, x2: 0, y2: 1 },
            stops: [
              [0, toRgba(color, 0.7)],
              [1, toRgba(color, 0.1)],
            ],
          },
          lineColor: color,
          ...(entry.timeStyle?.includes('OVERLAPPED') && { pointPadding: 0.1 * index }),
        }
      }),
    }
  }

  function getSeries(data, entry) {
    const configuredNames = getConfiguredNames(entry)

    if (data?.__prebuiltType === 'prebuilt_series') {
      if (data.length) {
        return data.map((item, index) => ({
          name: item.label || item.key || configuredNames[index] || `series_${index + 1}`,
          data: item.data || [],
        }))
      }
      return configuredNames.map(name => ({ name, data: [] }))
    }

    return configuredNames.map(name => ({
      name,
      data: data.map(row => [getTimestamp(row.time_trunc), Number(row[name]) || 0]).filter(point => point[0] !== null),
    }))
  }

  function getConfiguredNames(entry) {
    return (entry.timeDataColumns || []).map(column => column.trim().split(/\s+/).pop()).filter(Boolean)
  }

  function getColors(entry) {
    if (Array.isArray(entry.colors) && entry.colors.length) return entry.colors
    if (typeof entry.colors === 'string' && entry.colors.trim()) {
      return entry.colors
        .split(',')
        .map(color => color.trim())
        .filter(Boolean)
    }
    return DEFAULT_COLORS
  }

  function getChartType(entry) {
    if (entry.timeStyle === 'LINE') return 'spline'
    if (entry.timeStyle?.startsWith('BAR')) return 'column'
    return 'areaspline'
  }

  function getTimestamp(value) {
    if (typeof value === 'number') return value
    if (value && typeof value.time === 'number') return value.time
    const timestamp = Date.parse(value)
    return Number.isNaN(timestamp) ? null : timestamp
  }

  function formatAxisValue(value, units) {
    return units === 'bytes' || units === 'bytes/s' ? formatValue(value, units) : value
  }

  function formatValue(value, units) {
    if (units !== 'bytes' && units !== 'bytes/s') return value
    const byteUnits = units === 'bytes/s' ? ['B/s', 'kB/s', 'MB/s', 'GB/s'] : ['B', 'KB', 'MB', 'GB', 'TB']
    let result = Number(value) || 0
    let index = 0
    while (Math.abs(result) >= 1000 && index < byteUnits.length - 1) {
      result /= 1000
      index += 1
    }
    return `${parseFloat(result.toFixed(2))} ${byteUnits[index]}`
  }

  function toRgba(color, opacity) {
    const hex = color.replace('#', '')
    if (!/^(?:[\da-f]{3}|[\da-f]{6})$/i.test(hex)) return color
    const normalized =
      hex.length === 3
        ? hex
            .split('')
            .map(value => value + value)
            .join('')
        : hex
    const red = parseInt(normalized.slice(0, 2), 16)
    const green = parseInt(normalized.slice(2, 4), 16)
    const blue = parseInt(normalized.slice(4, 6), 16)
    return `rgba(${red}, ${green}, ${blue}, ${opacity})`
  }

  function getXAxisLabelFormats() {
    return {
      second: '%H:%M:%S',
      minute: '%H:%M',
      hour: '%H:%M',
      day: '%Y-%m-%d',
      week: '%e. %b',
      month: "%b '%y",
      year: '%Y',
    }
  }

  function getDataGroupingLabelFormats() {
    return {
      millisecond: ['%Y-%m-%d, %H:%M:%S', '%Y-%m-%d, %H:%M:%S', '-%H:%M:%S'],
      second: ['%Y-%m-%d, %H:%M:%S', '%Y-%m-%d, %H:%M:%S', '-%H:%M:%S'],
      minute: ['%Y-%m-%d, %H:%M', '%Y-%m-%d, %H:%M', '-%H:%M'],
      hour: ['%Y-%m-%d, %H:%M', '%Y-%m-%d, %H:%M', '%Y-%m-%d, %H:%M'],
      day: ['%Y-%m-%d'],
    }
  }
</script>

<style scoped>
  .report-graph {
    width: 100%;
    height: 100%;
    min-height: 220px;
  }
</style>
