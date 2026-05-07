<template>
  <reports :features="features" :cards="cards" :reports="reports" @view-report="onViewReport" />
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
      cards: ({ $store }) => $store.getters['reports/cardItems'],
      reports: ({ $store }) => $store.getters['reports/reportsLookup'],
    },

    mounted() {
      console.log('cards', this.cards)
      console.log('reports', this.reports)
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
