<template>
  <v-container fluid class="d-flex flex-column flex-grow-1 pa-2">
    <settings-shield ref="component" :settings="shieldSettings">
      <template #actions="{ newSettings, isDirty }">
        <u-btn class="mr-2" @click="onRefresh">
          {{ $vuntangle.$t('refresh') }}
        </u-btn>
        <u-btn :disabled="!isDirty" @click="onSave(newSettings)">
          {{ $vuntangle.$t('save') }}
        </u-btn>
      </template>
    </settings-shield>
  </v-container>
</template>

<script>
  import { SettingsShield } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import store from '@/store'
  import util from '@/util/util'

  export default {
    components: {
      SettingsShield,
    },
    mixins: [settingsMixin],

    provide() {
      return {
        $remoteData: () => ({
          interfaces: this.interfaces,
        }),
        $features: {
          hasIpv6Support: true,
        },
        $readOnly: false,
      }
    },

    computed: {
      // the shield settings from store
      shieldSettings: ({ $store }) => $store.getters['config/shieldSettings'],

      // the network settings from the store
      networkSettings: ({ $store }) => $store.getters['config/networkSetting'],

      /**
       * eturns the interfaces for condition value from network settings
       * @param {Object} vm.networkSettings
       */
      interfaces: ({ networkSettings }) => {
        return util.getInterfaceList(networkSettings, true, true)
      },
    },

    created() {
      this.fetchSettings(false, false)
    },

    methods: {
      /**
       * dispatches action to save the updated denial of service settings
       * @param {Object} newSettings - new settings to be saved
       */
      async onSave(newSettings) {
        const isValid = await this.$refs.component.validate()
        if (!isValid) return

        this.$store.commit('SET_LOADER', true)
        await store
          .dispatch('config/setShieldSettings', newSettings)
          .finally(() => this.$store.commit('SET_LOADER', false))
      },

      /**
       * Dispatches action to refresh the shield settings
       */
      onRefresh() {
        this.fetchSettings(true, true)
      },

      /**
       * Dispatches action to fetch the network and shield settings
       * @param shieldRefetch
       * @param networkRefetch
       */
      async fetchSettings(shieldRefetch, networkRefetch) {
        this.$store.commit('SET_LOADER', true)
        try {
          await Promise.all([
            this.$store.dispatch('config/getShieldSettings', shieldRefetch),
            this.$store.dispatch('config/getNetworkSettings', networkRefetch),
          ])
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Optional hook triggered on browser refresh.
       * Fetches updated shield and network settings and updates the store.
       */
      onBrowserRefresh() {
        this.fetchSettings(true, false)
      },
    },
  }
</script>
