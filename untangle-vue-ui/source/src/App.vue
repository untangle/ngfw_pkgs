<template>
  <blank-layout v-if="embedded || $route.name === 'login' || $route.name === 'setupwizard'" />
  <setup-layout v-else-if="$route.name.indexOf('setup') > -1" />
  <default-layout v-else />
</template>
<script>
  import { BlankLayout, DefaultLayout, SetupLayout } from '@/layouts'

  export default {
    components: { DefaultLayout, BlankLayout, SetupLayout },

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
