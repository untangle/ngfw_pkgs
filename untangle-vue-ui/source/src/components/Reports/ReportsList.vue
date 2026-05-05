<template>
  <reports :features="features" :reports-by-category="reportsByCategory" @view-report="onViewReport" />
</template>

<script>
  import { Reports } from 'vuntangle'
  import { urlEncode } from '@/util/reports'

  export default {
    components: { Reports },

    data() {
      return {
        features: {},
      }
    },

    computed: {
      reportsByCategory: ({ $store }) => $store.getters['reports/cardItems'],
    },

    methods: {
      onViewReport(uniqueId) {
        const entry = this.$store.getters['reports/allReports'].find(r => r.uniqueId === uniqueId)
        if (!entry) return
        this.$router.push(`/reports/${urlEncode(entry.category)}/${urlEncode(entry.title)}`)
      },
    },
  }
</script>
