<template>
  <div class="d-flex flex-column fill-height">
    <report-details
      v-if="view"
      :view="view"
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
       * reportMixin invokes `resolve(data)` with the row array.
       */
      async onFetchData({ resolve }) {
        if (!this.entry) {
          resolve([])
          return
        }
        const payload = await this.$store.dispatch('reports/fetchReportData', { uniqueId: this.entry.uniqueId })
        resolve(payload?.list || [])
      },
    },
  }
</script>
