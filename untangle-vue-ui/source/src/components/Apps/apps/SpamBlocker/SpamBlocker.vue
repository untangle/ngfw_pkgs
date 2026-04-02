<template>
  <spam-blocker
    :settings="settings"
    :app-data="consolidatedAppData"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    @toggle-state="toggleAppState"
    @remove-app="removeApp"
  >
    <!-- Custom action buttons slot -->
    <template #actions="{ newSettings, isDirty, validate }">
      <u-btn class="mr-2" @click="refreshData">
        {{ $t('refresh') }}
      </u-btn>
      <u-btn :disabled="!isDirty || saveDisabled" @click="onSave(newSettings, validate)">
        {{ $t('save') }}
      </u-btn>
    </template>
  </spam-blocker>
</template>

<script>
  import { SpamBlocker } from 'vuntangle'
  import appMixin from '../appMixin'

  export default {
    name: 'SpamBlockerApp',

    components: { SpamBlocker },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'spam-blocker',
        lastUpdate: null,
        lastUpdateCheck: null,
      }
    },

    computed: {
      // Display name for the app, falling back to a default if not provided in appData.
      appDisplayName: ({ appData }) => appData?.appProperties?.displayName || 'Spam Blocker',

      // Consolidated app data to pass to the SpamBlocker component,
      // including additional properties for last update timestamps.
      consolidatedAppData: ({ appData, powerState, lastUpdate, lastUpdateCheck }) => {
        return {
          ...appData,
          lastUpdate,
          lastUpdateCheck,
          powerState: powerState || {},
        }
      },
    },

    watch: {
      // Watcher for appManager from appMixin to trigger fetching of spam-blocker specific data when the manager becomes available.
      appManager: {
        async handler(manager) {
          if (!manager) return
          await this.fetchSpamBlockerData()
        },
      },
    },

    methods: {
      /**
       * Fetches spam-blocker specific data: last update time and last update check time.
       * Called when the appManager becomes available.
       */
      async fetchSpamBlockerData() {
        if (!this.appManager) return

        const [lastUpdate, lastUpdateCheck] = await Promise.all([
          new Promise(resolve => {
            this.appManager.getLastUpdate((res, ex) => resolve(ex ? null : res))
          }),
          new Promise(resolve => {
            this.appManager.getLastUpdateCheck((res, ex) => resolve(ex ? null : res))
          }),
        ])

        this.lastUpdate = lastUpdate
        this.lastUpdateCheck = lastUpdateCheck
      },

      /**
       * Validates all tabs and saves only if all fields are valid.
       * @param {Object} newSettings - Settings object to save
       * @param {Function} validate - validateTabs function from shared component
       */
      async onSave(newSettings, validate) {
        const isValid = await validate()
        if (!isValid) return
        this.saveSettings(newSettings)
      },

      /**
       * Refreshes the app data and re-fetches spam-blocker specific timestamps.
       */
      refreshData() {
        appMixin.methods.refreshData.call(this)
        this.fetchSpamBlockerData()
      },
    },
  }
</script>
