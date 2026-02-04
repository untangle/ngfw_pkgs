<template>
  <policy-manager :settings="settings">
    <template #actions="{ newSettings, isDirty, validate }">
      <u-btn class="mr-2">
        {{ $vuntangle.$t('refresh') }}
      </u-btn>
      <u-btn :disabled="!isDirty" @click="onSaveSettings(newSettings, validate)">{{ $t('save') }}</u-btn>
    </template>
  </policy-manager>
</template>

<script>
  import { PolicyManager } from 'vuntangle'
  import serviceMixin from './serviceMixin'

  export default {
    components: {
      PolicyManager,
    },
    mixins: [serviceMixin],

    data() {
      return {
        /* This is used to fetch the application's settings from the Vuex store. */
        appName: 'policy-manager',
      }
    },

    computed: {
      /**
       * Computed property that retrieves the settings for the application.
       * @returns {Object} The settings object for the current application.
       */
      settings() {
        return this.$store.getters['apps/getSettings'](this.appName)
      },
    },

    created() {
      /* Load application data */
      this.$store.dispatch('apps/loadAppData', 'policy-manager')
    },
  }
</script>
