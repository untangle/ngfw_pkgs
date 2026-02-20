<template>
  <div>
    <dynamic-layout
      v-if="
        embedded ||
        $route.name === 'login' ||
        $route.name === 'setupwizard' ||
        $route.name === 'wizard' ||
        $route.name === 'setup'
      "
    />
    <default-layout v-else />
  </div>
</template>
<script>
  import { DynamicLayout, DefaultLayout } from '@/layouts'

  export default {
    components: { DefaultLayout, DynamicLayout },

    data() {
      return {
        embedded: false,
      }
    },

    created() {
      // TODO - Consider different app flows setup, login, admin, reports
      // Below API calls are needed only for admin flow, so we can optimize by only calling them when needed

      // Application-level initialization
      // Load app views for all policies (provides initial app views data)
      this.$store.dispatch('apps/getAppViews', true)

      // Load policy-manager settings if installed
      this.$store.dispatch('apps/loadAppData', 'policy-manager')

      // Load reports on first navigation (after RPC is initialized)
      // This matches ExtJS Application.reportscheck() pattern
      // Fire and forget - don't block navigation
      if (!this.$store.getters['reports/isLoaded'] && !this.$store.getters['reports/loading']) {
        this.$store.dispatch('reports/loadReports')
      }

      // Use browser-level events to catch iframe destruction
      // These fire even when ExtJS destroys the iframe abruptly
      window.addEventListener('beforeunload', this.handleUnload)
      window.addEventListener('pagehide', this.handleUnload)
    },

    beforeMount() {
      this.embedded = window.location !== window.parent.location
      this._provided.embedded = this.embedded
    },

    beforeUnmount() {
      // Cleanup event listeners
      window.removeEventListener('beforeunload', this.handleUnload)
      window.removeEventListener('pagehide', this.handleUnload)
    },

    methods: {
      handleUnload() {
        // Set loader false when navigating away or when iframe is destroyed
        this.$store.commit('SET_LOADER', false)
      },
    },
  }
</script>
