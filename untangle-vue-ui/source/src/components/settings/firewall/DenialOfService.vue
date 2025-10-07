<template>
  <v-container fluid class="pa-0">
    <settings-shield ref="component" :settings="settings">
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
  import store from '@/store'
  import util from '@/util/util'

  export default {
    components: {
      SettingsShield,
    },

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
      settings: ({ $store }) => $store.getters['settings/shieldSettings'],

      // the network settings from the store
      networkSettings: ({ $store }) => $store.getters['settings/networkSetting'],

      /**
       * eturns the interfaces for condition value from network settings
       * @param {Object} vm.networkSettings
       */
      interfaces: ({ networkSettings }) => {
        return util.getInterfaceList(networkSettings, true, true)
      },
    },

    created() {
      store.dispatch('settings/getShieldSettings', false)
      store.dispatch('settings/getNetworkSettings', false)
    },

    methods: {
      /**
       * dispatches action to save the updated denial of service settings
       * @param {Object} newSettings - new settings to be saved
       */
      async onSave(newSettings) {
        console.log('Save Clicked With newSettings:', newSettings)
        const isValid = await this.$refs.component.validate()
        if (!isValid) return

        this.$store.commit('SET_LOADER', true)
        await store
          .dispatch('settings/setShieldSettings', newSettings)
          .finally(() => this.$store.commit('SET_LOADER', false))
      },

      /**
       * Dispatches action to refresh the shield settings
       */
      onRefresh() {
        this.$store.commit('SET_LOADER', true)
        store.dispatch('settings/getShieldSettings', true).finally(() => this.$store.commit('SET_LOADER', false))
      },
    },
  }
</script>
