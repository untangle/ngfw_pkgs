<template>
  <v-app>
    <app-nav />
    <app-drawer />
    <v-main class="d-flex">
      <u-error v-if="errorCaptured" />
      <keep-alive v-else :include="$store.state.cachedComponents">
        <router-view :key="$route.fullPath" />
      </keep-alive>
    </v-main>

    <v-overlay v-model="$store.state.pageLoad">
      <v-progress-circular indeterminate size="32" color="aristaBlue" />
    </v-overlay>

    <u-framework-dialog />
    <u-framework-confirm />
    <u-framework-toast />
  </v-app>
</template>

<script>
  import { captureException } from '@sentry/vue'
  import { UError } from 'vuntangle'
  import AppNav from './AppNav.vue'
  import AppDrawer from './AppDrawer.vue'

  export default {
    components: { AppNav, AppDrawer, UError },

    data: () => ({ errorCaptured: false }),
    watch: {
      $route: {
        immediate: true,
        handler() {
          // reset the error handler page so the user can navigate away from it
          this.errorCaptured = false
        },
      },
      errorCaptured(newErrorCaptured) {
        this.$emit('update:pageErrorCaptured', newErrorCaptured)
      },
    },
    errorCaptured(err) {
      captureException(err)
      this.errorCaptured = true
      // eslint-disable-next-line no-console
      console.error(err)

      return false
    },
  }
</script>
