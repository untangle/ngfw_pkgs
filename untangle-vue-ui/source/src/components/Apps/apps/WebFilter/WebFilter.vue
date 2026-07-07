<template>
  <web-filter
    :settings="settings"
    :app-data="consolidatedAppData"
    :tabs="webFilterAllTabs"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    @toggle-state="toggleAppState"
    @webfilter-lookup="handleSiteLookup"
    @webfilter:recategorize="handleRecategorize"
  >
    <template #actions="{ newSettings, isDirty }">
      <div class="d-flex flex-wrap align-center" style="gap: 8px">
        <div style="min-width: 140px">
          <u-app-status-remove class="mt-0" :app-name="appDisplayName" @remove="removeApp" />
        </div>
        <v-divider vertical class="mx-4" />
        <u-btn class="mr-2" @click="refreshData">{{ $t('refresh') }}</u-btn>
        <u-btn :disabled="!isDirty || saveDisabled" @click="saveSettings(newSettings)">{{ $t('save') }}</u-btn>
      </div>
    </template>
  </web-filter>
</template>

<script>
  import { WebFilter, UAppStatusRemove, webFilterAllTabs } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'
  import conditionDataMixin from '../conditionDataMixin'
  import { ngfwCapabilities } from './capabilities'
  import util from '@/util/util'

  export default {
    name: 'WebFilterApp',

    components: { WebFilter, UAppStatusRemove, VDivider },

    mixins: [appMixin, conditionDataMixin(['directory-connector'])],

    provide() {
      return {
        capabilities: ngfwCapabilities,
        $remoteData: () => ({
          interfaces: this.interfaces,
          directoryGroups: this.directoryGroups,
          directoryDomains: this.directoryDomains,
          directoryUsers: this.directoryUsers,
        }),
        $features: { isExpertMode: this.isExpertMode, hasFlaggedAction: true },
        $readOnly: false,
        $applications: {},
      }
    },

    props: {
      appData: { type: Object, default: null }, // The application data for the Web Filter app
    },

    data() {
      // Prepare the tabs for the WebFilter component, disabling the "site_lookup" tab if the power state is off.
      const tabs = webFilterAllTabs.map(tab => {
        if (tab.key === 'site_lookup') {
          return { ...tab, disabledWhen: () => !this.powerState?.on }
        }
        return tab
      })

      return {
        appName: this.appData?.appName || 'web-filter',
        defaultDisplayName: 'Web Filter',
        webFilterAllTabs: tabs,
      }
    },

    computed: {
      // Consolidated app data to pass to the WebFilter component.
      consolidatedAppData: appInstance => appInstance.buildConsolidatedAppData(),

      // Returns if the user is in expert mode from the store
      isExpertMode: ({ $store }) => $store.getters['config/isExpertMode'],

      // Returns the network settings from the store
      networkSettings: ({ $store }) => $store.getters['config/networkSetting'],

      // Returns the interfaces for condition value from network settings
      interfaces: ({ networkSettings }) => {
        return util.getInterfaceList(networkSettings, true, true)
      },
    },

    /**
     * Fetches the network settings when the component is created.
     */
    created() {
      this.$store.dispatch('config/getNetworkSettings', false)
    },

    methods: {
      /**
       * Handles the site lookup operation by invoking the appManager's lookupSite method.
       * If the appManager is not available, it resolves with an error message.
       * @param {Object} param0 - The parameters for the site lookup.
       * @param {string} param0.site - The site to look up.
       * @param {Function} param0.resolve - The callback to resolve the lookup result.
       * @returns {void}
       */
      handleSiteLookup({ site, resolve }) {
        if (!this.appManager) {
          resolve({ error: 'api_wf_lookup_unable_to_perform' })
          return
        }
        this.appManager.lookupSite((res, ex) => {
          if (ex) {
            resolve({ error: 'api_wf_lookup_unable_to_perform' })
            return
          }
          const cats = (res?.list || []).map(id => ({ cat: id }))
          resolve([{ cats }])
        }, site)
      },

      /**
       * Handles the recategorization of a site by invoking the appManager's recategorizeSite method.
       * If the appManager is not available, it resolves with an error message.
       * @param {Object} param0 - The parameters for the recategorization.
       * @param {string} param0.site - The site to recategorize.
       * @param {string} param0.categoryId - The new category ID for the site.
       * @param {Function} param0.resolve - The callback to resolve the recategorization result.
       * @returns {void}
       */
      handleRecategorize({ site, categoryId, resolve }) {
        if (!this.appManager) {
          resolve({ error: 'unable_to_submit_suggestion' })
          return
        }
        this.appManager.recategorizeSite(
          (res, ex) => {
            if (ex) {
              resolve({ error: 'unable_to_submit_suggestion' })
              return
            }
            resolve({ categoryId: res })
          },
          site,
          categoryId,
        )
      },
    },
  }
</script>
