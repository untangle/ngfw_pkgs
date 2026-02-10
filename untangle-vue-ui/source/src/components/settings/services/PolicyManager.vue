<template>
  <policy-manager :settings="settings" :apps-data="appsData" @build-apps="buildApps" @on-save="onSave">
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
       * @returns {Array} Array of policy objects
       */
      getAppsViews() {
        this.$store.dispatch('apps/getAppViews')
        return this.$store.getters['apps/appViews']
      },
      /**
       * Build apps list for a given policy.
       * This refreshes all policies data and builds the apps list for display.
       * @param {number} policyId - The policy ID to build apps for
       * @returns {Array} The list of apps for this policy
       */
      buildApps(policyId) {
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
          const runStates = policy.runStates?.map || {}
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

          const appsList = appProperties
            .filter(app => app.type === 'FILTER') // Only FILTER apps
            .map(app => {
              const instance = instancesMap.get(app.name)

              // Skip if NOT installable and NOT installed
              if (!installableSet.has(app.name) && !instance) return null

              if (instance) {
                // Detect parent policy (if instance belongs to a different policy)
                const parentPolicy =
                  instance.policyId && policy.policyId !== instance.policyId
                    ? policiesMap.get(instance.policyId)?.name || null
                    : null

                // Build state object for installed apps
                const state = {
                  instance,
                  runState: runStates[instance.id] || null,
                }

                return {
                  ...app,
                  instanceId: instance.id,
                  instance,
                  state,
                  parentPolicy,
                }
              }

              // Installable but not installed
              return {
                ...app,
                instanceId: null,
                instance: null,
                state: null,
                parentPolicy: null,
              }
            })
            .filter(Boolean) // Remove null entries from skipped apps

          // Store locally
          this.$set(this.policyApps, policyId, appsList)
          this.appsData = appsList
          return appsList
        } catch (err) {
          this.$set(this.policyApps, policyId, [])
          this.appsData = []
          return []
        }
      },
    },
  }
</script>
