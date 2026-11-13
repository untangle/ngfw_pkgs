export default {
  props: {
    interval: { type: Number, required: true },
  },
  data: () => ({
    refreshTimeout: null,
  }),
  mounted() {
    this.runRefresh()
  },
  activated() {
    this.runRefresh()
  },
  deactivated() {
    this.clearRefreshTimeout()
  },
  beforeDestroy() {
    this.clearRefreshTimeout()
  },
  methods: {
    clearRefreshTimeout() {
      clearTimeout(this.refreshTimeout)
      this.refreshTimeout = null
    },
    async runRefresh() {
      this.clearRefreshTimeout()
      await this.$store.dispatch('config/getMetricsAndStats', true)
      await this.loadData()
      if (this._isBeingDestroyed || this._isDestroyed) {
        return
      }
      if (this.interval) {
        this.refreshTimeout = setTimeout(() => this.runRefresh(), this.interval * 1000)
      }
    },
  },
}
