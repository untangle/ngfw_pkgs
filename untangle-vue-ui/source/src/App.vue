<template>
  <blank-layout
    v-if="embedded || $route.name === 'login' || $route.name === 'setupwizard' || $route.name === 'wizard'"
  />
  <!-- <setup-layout v-else-if="$route.name.indexOf('setup') > -1" /> -->
  <default-layout v-else />
</template>
<script>
  // SetupLayout
  import { BlankLayout, DefaultLayout } from '@/layouts'

  export default {
    // SetupLayout
    components: { DefaultLayout, BlankLayout },

    data() {
      return {
        embedded: false,
      }
    },

    beforeMount() {
      console.log('route', this.$route.name)
      console.log('embedded', this.embedded)
      console.log('window.location', window.location)

      this.embedded = window.location !== window.parent.location
    },
  }
</script>
