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

    beforeMount() {
      this.embedded = window.location !== window.parent.location
      this._provided.embedded = this.embedded
    },
  }
</script>
