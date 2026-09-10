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
  import interfaceMixin from './interfaceMixin'
  import { rpcCall } from '@/util/rpcHelpers'
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
        const result = await rpcCall(
          window.rpc?.UvmContext?.netspaceManager?.()?.isNetworkAvailable,
          ['networking', network],
          { fallback: null },
        )
        if (cb) {
          cb(result)
        }
        return (this.status = result)
      },

      // get the interface status
      async getInterfaceStatus() {
        const result = await rpcCall(window.rpc?.networkManager?.getInterfaceStatusV2, [this.device], {
          fallback: null,
        })

        return (this.status = result)
      },

      // renews DHCP and refetches status
      async onRenewDhcp(device, cb) {
        let interfaceId
        if (this.intfSetting?.device === device) interfaceId = this.intfSetting?.interfaceId
        else interfaceId = this.interfaces?.find(intf => intf.device === device)?.interfaceId
        if (interfaceId) {
          await rpcCall(window.rpc?.networkManager?.renewDhcpLease, [interfaceId], { fallback: null })
          await this.getInterfaceStatus()
        }
        cb()
      },

      /** returns box Wi-Fi channels */
      async onGetWifiChannels(countryCode, cb) {
        if (countryCode === '') {
          countryCode = await rpcCall(
            window.rpc?.networkManager?.getWirelessRegulatoryCountryCode,
            [this.intfSetting?.systemDev],
            { fallback: '' },
          )
        }
        const response = (await rpcCall(
          window.rpc?.networkManager?.getWirelessChannels,
          [this.intfSetting?.systemDev, countryCode],
          { fallback: null },
        )) || [{ frequency: this.$t('no_channel_match'), channel: -1 }]
        cb(response ?? null)
      },

      /** returns country codes */
      async onGetCountryItems(systemDev, cb) {
        const response = await rpcCall(
          window.rpc?.networkManager?.getWirelessValidRegulatoryCountryCodes,
          [systemDev],
          { fallback: null },
        )
        cb(response ?? null)
      },

      /** returns wireless channels */
      async onGetWirelessChannels(systemDev, newValue, cb) {
        const response = await rpcCall(window.rpc?.networkManager?.getWirelessChannels, [systemDev, newValue], {
          fallback: null,
        })
        cb(response ?? null)
      },

      /** returns wireless regulatory compliant */
      async onWirelessRegulatoryCompliant(systemDev, cb) {
        const response = await rpcCall(window.rpc?.networkManager?.isWirelessRegulatoryCompliant, [systemDev], {
          fallback: null,
        })
        cb(response ?? null)
      },

      /** fetches and returns whether the given interface is the VRRP master */
      async getVrrpMaster(interfaceId, cb) {
        const response = await rpcCall(window.rpc?.networkManager?.isVrrpMaster, [interfaceId], { fallback: null })
        cb(response ?? null)
      },

      async onSave(newSettings, validate) {
        const isValid = await validate()
        if (!isValid) return
        this.$store.commit('SET_LOADER', true)
        this.isSaving = true
        const resultIntf = await this.$store.dispatch('settings/setInterfaces', [newSettings]).finally(() => {
          this.isSaving = false
          this.$store.commit('SET_LOADER', false)
        })
        if (resultIntf?.success) {
          this.$vuntangle.toast.add(this.$t('network_settings_saved_successfully'))
        } else {
          this.$vuntangle.toast.add(this.$t('rolled_back_settings', [resultIntf.message]))
        }
        // return to main interfaces screen on success or error toast to avoid blank screen
        this.$router.push('/settings/network/interfaces')
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
