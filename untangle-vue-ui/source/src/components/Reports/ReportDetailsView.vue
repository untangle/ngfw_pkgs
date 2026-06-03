<template>
  <div class="d-flex flex-column fill-height">
    <report-details
      v-if="view"
      :view-override="view"
      :view-id="entry && entry.uniqueId"
      :show-report-selector="false"
      @fetch-data="onFetchData"
    />
    <div v-else-if="entry" class="d-flex flex-grow-1 align-center justify-center text--disabled">
      {{ entry.title }} ({{ entry.type }}) — not yet supported in Vue UI
    </div>
    <div v-else class="d-flex flex-grow-1 align-center justify-center text--disabled">Report not found</div>
  </div>
</template>

<script>
  import { ReportDetails } from 'vuntangle'
  import { buildReportView } from '@/util/reports'
  import { PROTOCOL_NAME_MAP } from '@/constants'

  export default {
    components: { ReportDetails },

    computed: {
      catSlug: ({ $route }) => $route.params.cat,
      repSlug: ({ $route }) => $route.params.rep,
      entry: ({ $store, catSlug, repSlug }) => $store.getters['reports/getReportBySlug'](catSlug, repSlug),
      view: ({ entry }) => buildReportView(entry),
    },

    methods: {
      /**
       * Bridge vuntangle's reportMixin `fetch-data` event to the NGFW Vuex action.
       * Uses getChartDataForReportEntry — backend pre-processes series, resolves
       * names, applies top-N slicing and returns plain ms timestamps.
       * No jabsorb normalization, no name map bootstrapping needed here.
       */
      async onFetchData({ query, resolve }) {
        if (!this.entry) {
          resolve([])
          return
        }

        const conditions = query?.userConditions || []
        const startMs = conditions.find(c => c.column === 'time_stamp' && c.operator === 'GT')?.value
        const endMs = conditions.find(c => c.column === 'time_stamp' && c.operator === 'LT')?.value

        const payload = await this.$store.dispatch('reports/fetchReportData', {
          uniqueId: this.entry.uniqueId,
          startDate: startMs != null ? new Date(startMs) : null,
          endDate: endMs != null ? new Date(endMs) : null,
        })

        const backendData = payload?.data
        if (backendData) {
          // PIE_GRAPH with protocol groupColumn: backend returns raw protocol numbers
          // as slice names. Resolve to human-readable names using the host-side IANA
          // map — static data, no backend access needed.
          if (Array.isArray(backendData.slices) && this.entry?.pieGroupColumn === 'protocol') {
            backendData.slices = backendData.slices.map(s => ({
              ...s,
              name: PROTOCOL_NAME_MAP[parseInt(s.name)] || s.name,
            }))
          }

          // Chart type: backend returned pre-built series or slices.
          // Resolve with the array so reportMixin data.length check works.
          // Attach a non-enumerable marker so getChartOptions detects the format
          // without interfering with forEach/JSON.stringify on the array.
          const arr = Array.isArray(backendData.series)
            ? backendData.series
            : Array.isArray(backendData.slices)
            ? backendData.slices
            : []
          const marker = Array.isArray(backendData.series) ? 'prebuilt_series' : 'prebuilt_slices'
          Object.defineProperty(arr, '__prebuiltType', { value: marker, enumerable: false, configurable: true })
          resolve(arr)
        } else {
          // Event/Text: raw row array
          resolve(payload?.list || [])
        }
      },
    },
  }
</script>
