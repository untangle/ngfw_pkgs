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
      @check-network-availability="isNetworkAvailable"
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
      features: {
        hasPppoe: true,
        hasNatIngress: true,
        hasBridged: true,
      },
    }),
    computed: {
      device: ({ $route }) => $route.params.device,
      type: ({ $route }) => $route.params.type,
      interfaces: ({ $store }) => $store.getters['settings/interfaces'],
      intfSetting: ({ interfaces, device }) => interfaces.find(intf => intf.device === device),
    },
    async mounted() {
      // Call getStatus conditionally only if not adding a new interface
      if (this.device) {
        await this.getInterfaceStatus()
      }
    },
    methods: {
      // check if network is available
      async isNetworkAvailable(network, cb) {
        const result = await new Promise((resolve, reject) => {
          window.rpc.UvmContext.netspaceManager().isNetworkAvailable(
            (res, err) => (err ? reject(err) : resolve(res)),
            'networking',
            network,
          )
        })
        if (cb) {
          cb(result)
        }
        return (this.status = result)
      },

      // get the interface status
      async getInterfaceStatus() {
        const result = await new Promise((resolve, reject) => {
          window.rpc.networkManager.getInterfaceStatusV2((res, err) => (err ? reject(err) : resolve(res)), this.device)
        })

        return (this.status = result)
      },

      // renews DHCP and refetches status
      async onRenewDhcp(device, cb) {
        try {
          let interfaceId
          if (this.intfSetting?.device === device) interfaceId = this.intfSetting?.interfaceId
          else interfaceId = this.interfaces?.find(intf => intf.device === device)?.interfaceId
          if (interfaceId) {
            await window.rpc.networkManager.renewDhcpLease(interfaceId)
            await this.getInterfaceStatus()
          }
          cb()
        } catch (ex) {
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
          this.isSaving = true
          // Save interface settings by updating the current/new interface- newSettings
          const resultIntf = await this.$store.dispatch('settings/setInterfaces', [newSettings])
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

      /** onDelete should be passed for the Edit Interface component.
       * this.intfSetting should represent the current interface being edited.
       * Pass the router with the interface path as a callback function,
       * which will be used for redirection after a successful operation.
       */
      onDelete() {
        this.deleteInterfaceHandler(this.intfSetting, () => {
          this.$router.push('/settings/network/interfaces')
        })
      },
    },
  }
</script>
