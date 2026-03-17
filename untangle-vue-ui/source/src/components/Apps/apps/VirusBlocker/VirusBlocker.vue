<template>
  <virus-blocker
    :settings="settings"
    :app-data="consolidatedAppData"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    @toggle-state="toggleAppState"
    @remove-app="removeApp"
  >
    <!-- Custom action buttons slot -->
    <template #actions="{ newSettings, isDirty }">
      <u-btn class="mr-2" @click="refreshData">
        {{ $t('refresh') }}
      </u-btn>
      <u-btn :disabled="!isDirty || saveDisabled" @click="saveSettings(newSettings)">
        {{ $t('save') }}
      </u-btn>
    </template>
  </virus-blocker>
</template>

<script>
  import { VirusBlocker } from 'vuntangle'
  import appMixin from '../appMixin'

  export default {
    name: 'VirusBlockerApp',

    components: {
      VirusBlocker,
    },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'virus-blocker',
        isFileScannerAvailable: false,
        lastSignatureUpdate: null,
      }
    },

    computed: {
      /**
       * Application display name
       */
      appDisplayName: ({ appData }) => appData?.appProperties?.displayName || 'Virus Blocker',

      /**
       * Consolidates app data with powerState and virus-blocker specific extra data
       */
      consolidatedAppData: ({ appData, powerState, lastSignatureUpdate, isFileScannerAvailable }) => {
        return {
          ...appData,
          isFileScannerAvailable,
          lastSignatureUpdate,
          powerState: powerState || {},
        }
      },
    },

    watch: {
      /**
       * Once appManager is available (set by appMixin.created), fetch virus-blocker specific data.
       */
      appManager: {
        async handler(manager) {
          if (!manager) return
          await this.fetchVirusBlockerData()
        },
      },
    },

    methods: {
      /**
       * Fetches virus-blocker specific data: file scanner availability and last signature update.
       * Uses appManager from appMixin.
       */
      async fetchVirusBlockerData() {
        if (!this.appManager) return

        const [isAvailable, lastUpdate] = await Promise.all([
          new Promise(resolve => {
            this.appManager.isFileScannerAvailable((res, ex) => resolve(ex ? false : res))
          }),
          new Promise(resolve => {
            this.appManager.getLastSignatureUpdate((res, ex) => resolve(ex ? null : res))
          }),
        ])

        this.isFileScannerAvailable = isAvailable
        this.lastSignatureUpdate = lastUpdate
      },
    },
  }
</script>
