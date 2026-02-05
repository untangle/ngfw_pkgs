<template>
  <policy-manager :settings="settings" @on-save="onSave">
    <template #actions="{ newSettings, isDirty, validate }">
      <u-btn class="mr-2" @click="loadAppData">
        {{ $vuntangle.$t('refresh') }}
      </u-btn>
      <u-btn :disabled="!isDirty" @click="onSave(newSettings, validate)">{{ $t('save') }}</u-btn>
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
      this.loadAppData()
    },

    methods: {
      /* Load application data */
      loadAppData() {
        this.$store.dispatch('apps/loadAppData', this.appName)
      },
      /**
       * Handles saving the new settings after validation.
       * @param {Object} newSettings - The new settings to be saved.
       * @param {Function} validate - The validation function to check settings.
       */
      async onSave(newSettings, validate) {
        this.$store.commit('SET_LOADER', true)
        if (validate && !(await validate())) return

        try {
          // await console.log('newSettings on Save:', newSettings)
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
