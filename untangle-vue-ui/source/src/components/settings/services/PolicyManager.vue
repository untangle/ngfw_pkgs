<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-2`">
    <no-license v-if="isLicensed === false" class="mt-2">
      {{ $t('not_licensed_service', [$t('policy_manager')]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right> mdi-open-in-new </v-icon>
        </u-btn>
      </template>
    </no-license>
    <policy-manager
      :settings="settings"
      :apps-data="appsData"
      :disabled="!isLicensed"
      :build-apps="buildApps"
      @on-save="onSave"
      @install-app="onInstallApp"
      @remove-app="onRemoveApp"
      @start-app="onStartApp"
      @stop-app="onStopApp"
    >
      <template #actions="{ newSettings, isDirty, validate }">
        <u-btn class="mr-2" @click="loadAppData">
          {{ $vuntangle.$t('refresh') }}
        </u-btn>
        <u-btn :disabled="!isDirty" @click="onSave(newSettings, validate)">{{ $t('save') }}</u-btn>
      </template>
    </policy-manager>
  </v-container>
</template>

<script>
  import { PolicyManager, NoLicense } from 'vuntangle'
  import serviceMixin from './serviceMixin'

  export default {
    components: {
      PolicyManager,
      NoLicense,
    },
    mixins: [serviceMixin],

    data() {
      return {
        /* This is used to fetch the application's settings from the Vuex store. */
        appName: 'policy-manager',
        licenseNodeName: 'policy-manager',
        policiesData: [], // all policies data from getAppsViews
        policyApps: {}, // apps data for each policy, keyed by policyId
        appsData: [], // apps data for the currently selected policy
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
          await this.$store.dispatch('apps/setAppSettings', {
            appName: this.appName,
            settings: newSettings,
          })
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
      /**
       * Get apps view for a specific policy.
       * This fetches all app-related data (properties, instances, installable apps, run states) for a given policy.
       */
      getAppsView(policyId) {
        this.$store.dispatch('apps/getAppView', policyId)
        return this.$store.getters['apps/getAppViewByPolicy'](policyId)
      },
      /**
       * Get apps views for all policies.
       * This fetches app-related data for all policies in the system.
       * Typically called after installing/removing apps or when refreshing policy data.
       * @returns {Promise<Array>} Array of policy objects
       */
      getAppsViews() {
        this.$store.dispatch('apps/getAppViews', true)
        return this.$store.getters['apps/appViews']
      },
      /**
       * Build apps list for a given policy.
       * This refreshes all policies data and builds the apps list for display.
       * @param {number} policyId - The policy ID to build apps for
       * @returns {Promise<Array>} The list of apps for this policy
       */
      async buildApps(policyId) {
        try {
          // Refresh all policies apps views
          const allPoliciesData = this.getAppsViews()
          if (allPoliciesData) {
            this.policiesData = allPoliciesData
          }

          // Get current policy apps view
          const policy = this.getAppsView(policyId)

          if (!policy) {
            this.$set(this.policyApps, policyId, [])
            this.appsData = []
            return []
          }

          const appProperties = policy.appProperties || []
          const instances = policy.instances || []
          const installable = policy.installable || []
          const runStates = policy.runStates || {}
          const licenseMap = policy.licenseMap || {}
          const allPolicies = this.settings?.policies || []

          // Early return if no apps to process
          if (appProperties.length === 0) {
            this.$set(this.policyApps, policyId, [])
            this.appsData = []
            return []
          }

          // Create lookup maps for O(1) access instead of O(n) find operations
          const instancesMap = new Map(instances.map(inst => [inst.appName, inst]))
          const installableSet = new Set(installable)
          const policiesMap = new Map(allPolicies.map(p => [p.policyId, p]))

          const appsListPromises = appProperties
            .filter(app => app.type === 'FILTER') // Only FILTER apps
            .map(async app => {
              const instance = instancesMap.get(app.name)
              const license = licenseMap[app.name] || null // Get license for this app

              if (!installableSet.has(app.name) && !instance) return null

              if (instance) {
                // Detect parent policy (if instance belongs to a different policy)
                const parentPolicy =
                  instance.policyId && policy.policyId !== instance.policyId
                    ? policiesMap.get(instance.policyId)?.name || null
                    : null

                const runState = runStates[instance.id] || null

                // Build state object for installed apps
                // checkLicense = false matches ExtJS Policy Manager behavior (no vm provided)
                const state = await this.buildAppState(instance, runState, app, false)

                return {
                  ...app,
                  instanceId: instance.id,
                  instance,
                  state,
                  parentPolicy,
                  license, // Include license in app object
                }
              }

              // Installable but not installed
              return {
                ...app,
                instanceId: null,
                instance: null,
                state: null,
                parentPolicy: null,
                license, // Include license even for non-installed apps
              }
            })

          const appsList = (await Promise.all(appsListPromises)).filter(Boolean).sort((a, b) => {
            return (a.viewPosition || 0) - (b.viewPosition || 0)
          })

          this.$set(this.policyApps, policyId, appsList)
          this.appsData = appsList
          return appsList
        } catch (err) {
          this.$set(this.policyApps, policyId, [])
          this.appsData = []
          return []
        }
      },

      /**
       * Build app state object from instance and runState
       * This creates a UI-ready state object with status, color, and on/off information
       * - "Enabled" when targetState = RUNNING → Green
       * - "Disabled" when targetState != RUNNING → Grey
       * - "Disabled, license is invalid or expired" when license is invalid (only if checkLicense = true) → Red
       * @param {Object} instance - The app instance
       * @param {Object} runState - The run state from backend (can be null)
       * @param {Object} appProperties - App properties object (contains daemon property if applicable)
       * @param {Boolean} checkLicense - Whether to check license validity
       * @returns {Promise<Object>} State object with status, colorCls, on, and inconsistent properties
       */
      async buildAppState(instance, runState, appProperties = null, checkLicense = false) {
        if (!instance) return null

        const targetState = instance.targetState
        const runStateValue = runState || 'INITIALIZED'

        // Determine if app is running
        const isOn = runStateValue === 'RUNNING'

        let daemonRunning = true
        if (isOn && appProperties && appProperties.daemon != null) {
          daemonRunning = await this.isDaemonRunning(appProperties.daemon)
        }

        // Check if state is inconsistent
        const inconsistent = targetState !== runStateValue || (runStateValue === 'RUNNING' && !daemonRunning)

        // Check license validity
        let expired = false
        if (checkLicense && appProperties && appProperties.name) {
          const isValid = await this.isAppLicenseValid(appProperties.name)
          expired = !isValid
        }

        // Power flag indicates transition state (starting/stopping)
        const power = false

        let status = ''
        let colorCls = ''

        if (isOn) {
          if (power) {
            status = this.$vuntangle.$t('powering_on')
            colorCls = 'warning'
          } else if (inconsistent) {
            status = this.$vuntangle.$t('enabled_but_not_active')
            colorCls = 'error'
          } else {
            status = this.$vuntangle.$t('enabled')
            colorCls = 'success'
          }
        } else if (power) {
          status = this.$vuntangle.$t('powering_off')
          colorCls = 'warning'
        } else if (expired) {
          status = this.$vuntangle.$t('Disabled, license is invalid or expired')
          colorCls = 'error'
        } else if (inconsistent) {
          status = this.$vuntangle.$t('disabled_but_active')
          colorCls = 'error'
        } else {
          status = this.$vuntangle.$t('disabled')
          colorCls = 'grey'
        }

        return {
          instance,
          runState,
          on: isOn,
          status,
          colorCls,
          power,
          inconsistent,
          expired,
        }
      },

      /**
       * Install an app for a specific policy
       * @param {Object} payload - Contains appName and policyId
       */
      async onInstallApp({ appName, policyId }) {
        this.$store.commit('SET_LOADER', true)
        try {
          await this.$store.dispatch('apps/instantiateApp', { appName, policyId })
          this.buildApps(policyId)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Remove an installed app
       * @param {Object} payload - Contains instanceId and policyId
       */
      async onRemoveApp({ instanceId, policyId }) {
        this.$store.commit('SET_LOADER', true)
        try {
          await this.$store.dispatch('apps/destroyApp', { instanceId, policyId })
          this.buildApps(policyId)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Start an installed app
       * @param {Object} payload - Contains instanceId and policyId
       */
      async onStartApp({ instanceId, policyId }) {
        this.$store.commit('SET_LOADER', true)
        try {
          await this.$store.dispatch('apps/startApp', { instanceId, policyId })
          this.buildApps(policyId)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Stop a running app
       * @param {Object} payload - Contains instanceId and policyId
       */
      async onStopApp({ instanceId, policyId }) {
        this.$store.commit('SET_LOADER', true)
        try {
          await this.$store.dispatch('apps/stopApp', { instanceId, policyId })
          this.buildApps(policyId)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
