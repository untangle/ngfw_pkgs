<template>
  <v-container>
    <settings-interface
      ref="component"
      :settings="settingsObject"
      :is-saving="isSaving"
      :type="type"
      :interfaces="interfaces"
      :interface-statuses="interfaceStatuses"
      @delete="onDelete"
      @get-wifi-channels="onGetWifiChannels"
      @get-country-code-items="onGetCountryItems"
      @get-wireless-channels="onGetWirelessChannels"
      @get-wireless-regulatory-compliant="onWirelessRegulatoryCompliant"
    >
      <template #actions="{ isDirty, validate }">
        <u-btn to="/settings/network/interfaces" class="mr-2">{{ $t('back_to_list') }}</u-btn>
        <u-btn :min-width="null" :disabled="!isDirty" @click="onSave(validate)">
          {{ $t('save') }}
        </u-btn>
      </template>
    </settings-interface>
  </v-container>
</template>

<script>
  import { SettingsInterface } from 'vuntangle'
  import Util from '../../../util/setupUtil'
  import defaults from '../network/SettingsInterface/defaults'
  import interfaceMixin from './interfaceMixin'

  export default {
    components: {
      SettingsInterface,
    },
    mixins: [interfaceMixin],
    data: () => ({
      isSaving: false,
    }),
    computed: {
      device: ({ $route }) => $route.params.device,
      type: ({ $route }) => $route.params.type,
      interfaces: ({ $store }) => $store.getters['settings/interfaces'],
      settings: ({ $store }) => $store.getters['settings/networkSetting'],
      interfaceStatuses: ({ $store }) => $store.getters['settings/interfaceStatuses'],

      // Determine if editing existing or creating new interface
      settingsObject() {
        const existing = this.device ? this.interfaces.find(i => i.systemDev === this.device) : null

        // If editing, return existing interface
        if (existing) return existing

        // If adding, return cloned default settings
        if (this.type && defaults[this.type]) {
          return { ...defaults[this.type] }
        }

        // Fallback empty object
        return {}
      },
    },
    methods: {
      /** returns box Wi-Fi channels */
      async onGetWifiChannels(countryCode, cb) {
        if (countryCode === '') {
          countryCode = await window.rpc.networkManager.getWirelessRegulatoryCountryCode(this.settings.systemDev)
        }
        const response = (await window.rpc.networkManager.getWirelessChannels(
          this.settings.systemDev,
          countryCode,
        )) || [{ frequency: this.$t('no_channel_match'), channel: -1 }]
        cb(response ?? null)
      },

      /** returns country codes */
      async onGetCountryItems(systemDev, cb) {
        const response = await window.rpc.networkManager.getWirelessValidRegulatoryCountryCodes(systemDev)
        cb(response ?? null)
      },
      /** returns wireless channels */
      async onGetWirelessChannels(systemDev, newValue, cb) {
        const response = await window.rpc.networkManager.getWirelessChannels(systemDev, newValue)
        cb(response ?? null)
      },

      /** returns wireless regulatory compliant */
      async onWirelessRegulatoryCompliant(systemDev, cb) {
        const response = await window.rpc.networkManager.isWirelessRegulatoryCompliant(systemDev)
        cb(response ?? null)
      },

      async onSave(validate) {
        try {
          const isValid = await validate()
          if (!isValid) return

          this.isSaving = true
          this.$store.commit('SET_LOADER', true)

          const intfToSave = this.$refs.component.settingsCopy
          if (Util.isDestroyed(this, intfToSave)) {
            this.isSaving = false
            this.$store.commit('SET_LOADER', false)
            return
          }
          const cb = this.$store.state.setEditCallback
          if (cb) cb()

          await this.$store.dispatch('settings/setInterface', intfToSave)
          this.isSaving = false
          this.$store.commit('SET_LOADER', false)
          this.$router.push('/settings/network/interfaces')
        } catch (ex) {
          this.isSaving = false
          this.$store.commit('SET_LOADER', false)
          Util.handleException(ex)
        }
      },

      onDelete() {
        this.deleteInterfaceHandler(this.settings, () => {
          this.$router.push('/settings/network/interfaces')
        })
      },
    },
  }
</script>
