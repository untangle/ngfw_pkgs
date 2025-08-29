<template>
  <static-routes
    :settings="routes"
    :interfaces="interfaces"
    :current-routes-data="currentRoutes"
    class="pa-2"
    @refresh-current-routes="fetchCurrentRoutes"
    @refresh="onRefresh"
  >
    <template #actions="{ newSettings, isDirty }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSave(newSettings)">
        {{ $t('save') }}
      </u-btn>
    </template>
  </static-routes>
</template>
<script>
  import { cloneDeep } from 'lodash'
  import { StaticRoutes } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import Rpc from '@/util/Rpc'
  import Util from '@/util/setupUtil'

  export default {
    components: { StaticRoutes },
    mixins: [settingsMixin],

    data() {
      return {
        currentRoutes: null,
      }
    },

    computed: {
      // Routes is coming from the networkSettings from store
      routes: ({ $store }) => $store.getters['settings/staticRoutes'],
      // Interfaces from store which is need to be shown in the Next Hop
      interfaces: ({ $store }) => $store.getters['settings/interfaces'],
      // the network settings from the store
      networkSettings: ({ $store }) => $store.getters['settings/networkSetting'],
    },

    created() {
      this.fetchSettings(false)
      this.fetchCurrentRoutes()
    },

    methods: {
      /**
       * The fetchCurrentRoutes function is triggered every time the screen is displayed.
       * To refresh the current routes, we use the same function.
       */
      async fetchCurrentRoutes() {
        this.$store.commit('SET_LOADER', true)
        try {
          const data = await Rpc.asyncData('rpc.networkManager.getStatus', 'ROUTING_TABLE', null)
          this.currentRoutes = data
          return data
        } catch (err) {
          Util.handleException(err)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Fetches the settings and updates the store.
       * If refetch is true, it forces a re-fetch of the settings.
       * @param {boolean} refetch - Whether to force a re-fetch of the settings.
       */
      async fetchSettings(refetch) {
        await this.$store.dispatch('settings/getNetworkSettings', refetch)
      },

      onRefresh() {
        this.fetchSettings(true)
      },

      async onSave(updatedRoutes) {
        this.$store.commit('SET_LOADER', true)
        const routes = await updatedRoutes?.map(route => {
          /**
           * If nextHop is an object (interface), replace it with its interfaceId.
           * The selected object is converted into a string by using its interfaceId.
           * If it is already a string, the value remains unchanged.
           */
          if (route.nextHop && typeof route.nextHop === 'object' && route.nextHop.interfaceId) {
            return {
              ...route,
              nextHop: String(route.nextHop.interfaceId), // convert id into the string
            }
          }
          return route
        })
        const networkSettingsCopy = cloneDeep(this.networkSettings)
        networkSettingsCopy.staticRoutes = routes
        await Promise.all([this.$store.dispatch('settings/setNetworkSettingV2', networkSettingsCopy)]).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
      },

      /**
       * Optional hook triggered on browser refresh.
       * Fetches updated network settings and updates the store.
       */
      onBrowserRefresh() {
        this.fetchSettings(true)
      },
    },
  }
</script>
