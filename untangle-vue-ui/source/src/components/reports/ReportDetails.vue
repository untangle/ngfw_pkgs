<template>
  <div class="d-flex flex-column fill-height">
    <report-details
      :view-id="selectedUniqueId"
      :categories="categoriesForNav"
      :show-report-selector="true"
      :is-local-ui="false"
      @fetch-data="onFetchData"
      @view-report="onViewReport"
    />
  </div>
</template>

<script>
  import { mapGetters } from 'vuex'
  import { ReportDetails } from 'vuntangle'
  import reportsMixin from './reportsMixin'
  import { urlEncode } from '@/util/reports'

  export default {
    components: { ReportDetails },

    mixins: [reportsMixin],

    provide() {
      return {
        $dateTimeRangeComponent: 'date-time-range-presets',
        $serverTimezoneOffsetMs: () => this.timeZoneOffset,
        $serverClockOffsetMs: () => this.serverClockOffsetMs,
      }
    },

    computed: {
      ...mapGetters('reports', ['categoriesForNav']),
      ...mapGetters('config', ['timeZoneOffset', 'serverClockOffsetMs']),

      selectedUniqueId() {
        return this.allReports.find(
          r => urlEncode(r.category) === this.$route.params.cat && urlEncode(r.title) === this.$route.params.rep,
        )?.uniqueId
      },
    },

    methods: {
      onFetchData({ resolve }) {
        resolve([])
      },
    },
  }
</script>
