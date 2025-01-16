<template>
  <blank-layout v-if="embedded || $route.name === 'login' || $route.name === 'setupwizard'" />
  <default-layout v-else />
</template>
<script>
  import { BlankLayout, DefaultLayout } from '@/layouts'

  export default {
    components: { DefaultLayout, BlankLayout },

    data() {
      return {
        embedded: false,
      }
    },

    beforeMount() {
      this.embedded = window.location !== window.parent.location
    },
  }
</script>
