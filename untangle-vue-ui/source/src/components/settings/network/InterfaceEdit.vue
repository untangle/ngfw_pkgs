<template>
  <v-container>
    <settings-interface
      ref="component"
      :settings="intfSetting"
      :is-saving="isSaving"
      :type="type"
      :interfaces="interfaces"
      :status="status"
      :features="features"
      @renew-dhcp="onRenewDhcp"
      @delete="onDelete"
      @get-wifi-channels="onGetWifiChannels"
      @get-country-code-items="onGetCountryItems"
      @get-wireless-channels="onGetWirelessChannels"
      @get-wireless-regulatory-compliant="onWirelessRegulatoryCompliant"
      @get-vrrp-master="getVrrpMaster"
    >
      <template #actions="{ newSettings, isDirty, validate }">
        <u-btn to="/settings/network/interfaces" class="mr-2">{{ $t('back_to_list') }}</u-btn>
        <u-btn :min-width="null" :disabled="!isDirty" @click="onSave(newSettings, validate)">
          {{ $t('save') }}
        </u-btn>
      </template>
    </settings-interface>
  </v-container>
</template>

<script>
  import { SettingsInterface } from 'vuntangle'
  import Util from '../../../util/setupUtil'
  import interfaceMixin from './interfaceMixin'
  export default {
    components: {
      SettingsInterface,
    },
    mixins: [interfaceMixin],
    data: () => ({
      status: null,
      isSaving: false,
      features: {},
    }),
    computed: {
      device: ({ $route }) => $route.params.device,
      type: ({ $route }) => $route.params.type,
      interfaces: ({ $store }) => $store.getters['settings/interfaces'],
      intfSetting: ({ $store, device }) => $store.getters['settings/interface'](device),
    },
    async mounted() {
      await this.setFeatures()
      // Call getStatus conditionally only if not adding a new interface
      if (this.device) {
        await this.getInterfaceStatus()
      }
      // set the help context for this device type (e.g. interfaces_wwan)
      this.$store.commit('SET_HELP_CONTEXT', `interfaces_${(this.type || this.intfSetting?.type).toLowerCase()}`)
    },
    methods: {
      setFeatures() {
        this.features.hasPppoe = true
        this.features.hasNatIngress = true
        this.features.hasBridged = true
      },

      // get the interface status
      getInterfaceStatus() {
        return new Promise((resolve, reject) => {
          window.rpc.networkManager.getAllInterfacesStatusV2((result, error) => {
            if (error) {
              reject(error)
              return
            }
            if (result && Array.isArray(result)) {
              this.status = result.find(item => item.device === this.device)
            }
            resolve(this.status)
          })
        })
      },
      // get dhcp result
      getRenewDhcpLease(interfaceId) {
        return new Promise((resolve, reject) => {
          window.rpc.networkManager.renewDhcpLease(resolve, reject, interfaceId)
        })
      },

      // renews DHCP and refetches status
      async onRenewDhcp(device, cb) {
        try {
          const interfaceToUpdate = this.interfaces.find(i => i.device === device)
          const interfaceId = interfaceToUpdate.interfaceId
          await this.getRenewDhcpLease(interfaceId)
          const statusResult = await this.getInterfaceStatus()

          if (Util.isDestroyed(this)) {
            return
          }
          if (statusResult) {
            const statusWithoutId = { ...statusResult }
            delete statusWithoutId.interfaceId
            Object.assign(interfaceToUpdate, statusWithoutId) // update interface with the new values
          }
          cb()
        } catch (ex) {
          this.$vuntangle.toast.add(ex)
          Util.handleException(ex)
        }
      },

      /** returns box Wi-Fi channels */
      async onGetWifiChannels(countryCode, cb) {
        if (countryCode === '') {
          countryCode = await window.rpc.networkManager.getWirelessRegulatoryCountryCode(this.intfSetting?.systemDev)
        }
        const response = (await window.rpc.networkManager.getWirelessChannels(
          this.intfSetting?.systemDev,
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

      /** fetches and returns whether the given interface is the VRRP master */
      async getVrrpMaster(interfaceId, cb) {
        const response = await window.rpc.networkManager.isVrrpMaster(interfaceId)
        cb(response ?? null)
      },

      async onSave(newSettings, validate) {
        try {
          const isValid = await validate()
          if (!isValid) return
          // push changes via store actions
          this.$store.commit('SET_LOADER', true)
          if (Util.isDestroyed(this)) {
            return
          }
          this.isSaving = true
          // Save interface settings by updating the current interface- newSettings
          const resultIntf = await this.$store.dispatch('settings/setInterface', newSettings)
          if (resultIntf?.success) {
            this.$vuntangle.toast.add(this.$t('network_settings_saved_successfully'))
          } else {
            this.$vuntangle.toast.add(this.$t('rolled_back_settings', [resultIntf.message]))
          }
          // return to main interfaces screen on success or error toast to avoid blank screen
          this.$router.push('/settings/network/interfaces')
        } catch (ex) {
          Util.handleException(ex)
        } finally {
          this.isSaving = false
          this.$store.commit('SET_LOADER', false)
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
