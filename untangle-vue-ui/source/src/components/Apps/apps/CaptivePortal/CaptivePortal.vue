<template>
  <captive-portal
    :settings="settings"
    :app-data="consolidatedAppData"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    :active-users="activeUsers"
    @toggle-state="toggleAppState"
    @logout-user="logoutUser"
    @refresh-active-users="fetchActiveUsers"
  >
    <!-- Custom action buttons slot -->
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
  </captive-portal>
</template>

<script>
  import { CaptivePortal, UAppStatusRemove } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'
  import util from '@/util/util'

  export default {
    name: 'CaptivePortalApp',

    components: { CaptivePortal, UAppStatusRemove, VDivider },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    provide() {
      return {
        $remoteData: () => ({
          interfaces: this.interfaces,
        }),
        $features: {},
        $readOnly: false,
        $applications: {},
      }
    },

    data() {
      return {
        appName: this.appData?.appName || 'captive-portal',
        activeUsers: [],
      }
    },

    computed: {
      appDisplayName: ({ appData }) => appData?.appProperties?.displayName || 'Captive Portal',

      consolidatedAppData: ({ appData, powerState }) => {
        return {
          ...appData,
          powerState: powerState || {},
        }
      },

      // the network settings from the store
      networkSettings: ({ $store }) => $store.getters['config/networkSetting'],

      /**
       * returns the interfaces for condition value from network settings
       * @param {Object} vm.networkSettings
       */
      interfaces: ({ networkSettings }) => {
        return util.getInterfaceList(networkSettings, true, true)
      },
    },

    // Fetch the required settings when the component is created
    created() {
      this.fetchRequiredSettings(false)
    },

    watch: {
      appManager: {
        async handler(manager) {
          if (!manager) return
          await this.fetchActiveUsers()
        },
      },
    },

    methods: {
      /**
       * Fetches the list of active users from the app manager and updates the component state.
       */
      async fetchActiveUsers() {
        if (!this.appManager) return

        const users = await new Promise(resolve => {
          this.appManager.getActiveUsersV2((result, ex) => {
            if (ex) {
              resolve([])
            } else {
              resolve(result?.list || result || [])
            }
          })
        })

        this.activeUsers = users
      },

      /**
       * logout user by userAddress
       * @param userAddress User Address to logout
       */
      async logoutUser(userAddress) {
        if (!this.appManager || !userAddress) return

        await new Promise(resolve => {
          this.appManager.userAdminLogout(result => {
            resolve(result)
          }, userAddress)
        })

        await this.fetchActiveUsers()
      },

      /**
       * Fetches the required settings for the app, e.g. the network settings.
       * This method can be called with a parameter to indicate whether to refetch the network settings from the store.
       * @param {boolean} networkRefetch - Indicates whether to refetch the network settings from the store.
       */
      fetchRequiredSettings(networkRefetch) {
        this.$store.dispatch('config/getNetworkSettings', networkRefetch)
      },

      /**
       * Overrides the refreshData method from appMixin to also refresh the active users list when the main app data is refreshed.
       * This ensures that the UI reflects the most up-to-date information about active users whenever a refresh is triggered.
       */
      refreshData() {
        appMixin.methods.refreshData.call(this)
        this.fetchActiveUsers()
        this.fetchRequiredSettings(true)
      },
    },
  }
</script>
