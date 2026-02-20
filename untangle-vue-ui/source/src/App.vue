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
    <quarantine-layout v-else-if="$route.meta.layout && $route.meta.layout.name === 'QuarantineLayout'" />
    <default-layout v-else />
  </div>
</template>
<script>
  import { DynamicLayout, DefaultLayout, QuarantineLayout } from '@/layouts'

  export default {
    components: { DefaultLayout, DynamicLayout, QuarantineLayout },

    data() {
      return {
        embedded: false,
      }
    },

    created() {
      if (window.rpc) {
        // Application-level initialization
        // Load app views for all policies (provides initial app views data)
        this.$store.dispatch('apps/getAppViews', true)

        // Load policy-manager settings if installed
        this.$store.dispatch('apps/loadAppData', 'policy-manager')
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
