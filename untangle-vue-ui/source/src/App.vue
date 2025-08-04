<template>
  <div>
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
