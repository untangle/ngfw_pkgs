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
      // Use browser-level events to catch iframe destruction
      // test
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
      // Handle iframe destruction by resetting the loader state
      handleUnload() {
        this.$store.commit('SET_LOADER', false)
      },
    },
  }
</script>
