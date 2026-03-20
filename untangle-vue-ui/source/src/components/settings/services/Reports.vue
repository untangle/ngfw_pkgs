<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-0`">
    <reports-app :settings="settings" @save-settings="onSaveSettings" @refresh-settings="loadAppData" />
  </v-container>
</template>

<script>
  import { ReportsApp } from 'vuntangle'
  import serviceMixin from './serviceMixin'

  export default {
    components: {
      ReportsApp,
    },
    mixins: [serviceMixin],

    data() {
      return {
        /* This is used to fetch the application's settings from the Vuex store. */
        appName: 'reports',
        licenseNodeName: 'reports',
      }
    },

    computed: {
      /**
       * Computed property that retrieves the settings for the application.
       * @returns {Object} The settings object for the current application.
       */
      settings() {
        return this.$store.getters['apps/getSettings'](this.appName)?.settings
      },

      /* Gets the expert mode status from the settings */
      isExpertMode: ({ $store }) => $store.getters['config/isExpertMode'],
    },

    created() {
      this.loadAppData()
    },

    methods: {
      /* Load application data */
      loadAppData() {
        this.$store.dispatch('apps/loadAppData', { appName: this.appName })
      },

      /**
       * Handle save settings event from the Reports component
       * @param {Object} payload - The payload object containing new settings
       * @param {Object} payload.newSettings - The updated settings object to save
       */
      async onSaveSettings({ newSettings }) {
        this.$store.commit('SET_LOADER', true)
        try {
          await this.$store.dispatch('apps/setAppSettings', {
            appName: this.appName,
            settings: newSettings,
          })
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
