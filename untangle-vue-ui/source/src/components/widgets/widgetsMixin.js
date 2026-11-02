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
      // clear any previous refresh timer
      this.clearRefreshTimeout()

      // wait for all data to load
      await this.loadData()

      if (this._isBeingDestroyed || this._isDestroyed) {
        return
      }

      // set to run the refresh again
      if (this.interval) {
        this.refreshTimeout = setTimeout(this.runRefresh, this.interval * 1000)
      }
    },
  },
}
