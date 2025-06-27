<template>
  <div>
    <AppVariantInjector />
    <blank-layout
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
  import { AppVariantInjector } from 'vuntangle'
  import { BlankLayout, DefaultLayout } from '@/layouts'

  export default {
    components: { DefaultLayout, BlankLayout, AppVariantInjector },

    provide() {
      return {
        APP_VARIANT: 'NGFW',
      }
    },
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
