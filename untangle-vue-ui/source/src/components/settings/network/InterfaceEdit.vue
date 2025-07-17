<template>
  <v-container>
    <settings-interface
      ref="component"
      :settings="settings"
      :is-saving="isSaving"
      :type="type"
      :interfaces="interfaces"
      :interface-statuses="interfaceStatuses"
      :status="status"
      :features="features"
      @renew-dhcp="onRenewDhcp"
      @delete="onDelete"
      @get-wifi-channels="onGetWifiChannels"
      @get-country-code-items="onGetCountryItems"
      @get-wireless-channels="onGetWirelessChannels"
      @get-wireless-regulatory-compliant="onWirelessRegulatoryCompliant"
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
      isBridged: undefined,
      bridgedInterfaceName: undefined,
      isSaving: false,
      features: {},
    }),
    computed: {
      device: ({ $route }) => $route.params.device,
      type: ({ $route }) => $route.params.type,
      interfaces: ({ $store }) => $store.getters['settings/interfaces'],
      settings: ({ $store, device }) => $store.getters['settings/interface'](device),
      interfaceStatuses: ({ $store }) => $store.getters['settings/interfaceStatuses'],
    },
    async mounted() {
      await this.setFeatures()
      this.isBridgedInterface()
      // Call getStatus conditionally only if not adding a new interface
      if (this.device) {
        this.status = await this.getInterfaceStatus(this.device)
      }
      // set the help context for this device type (e.g. interfaces_wwan)
      this.$store.commit('SET_HELP_CONTEXT', `interfaces_${(this.type || this.settings?.type).toLowerCase()}`)
    },
    methods: {
      setFeatures() {
        this.features.hasPppoe = true
        this.features.hasBridged = true
        this.features.hasGatewayMetric = this.settings.wan
        this.features.hasNatIngress = true
      },
      getInterfaceStatus(device) {
        return new Promise((resolve, reject) => {
          window.rpc.networkManager.getInterfaceStatusV2((result, error) => {
            if (error) {
              reject(error)
            } else {
              const interfaceStatus = result.list.find(item => item.device === device)
              resolve(interfaceStatus)
            }
          })
        })
      },
      getIntfId() {
        return new Promise((resolve, reject) => {
          window.rpc.networkManager.renewDhcpLease((result, error) => {
            if (error) {
              reject(error)
            } else {
              resolve(result)
            }
          }, this.settings.interfaceId)
        })
      },
      // renews DHCP and refetches status
      async onRenewDhcp(device, cb) {
        // await api.post(`/api/renewdhcp/${device}`)
        const [intfIdResult, interfaceStatusResult] = await Promise.all([
          this.getIntfId(),
          this.getInterfaceStatus(device),
        ])
        console.log('intfIdResult :', intfIdResult)
        if (Util.isDestroyed(this)) {
          return
        }
        // const intfStatus = interfaceStatusResult.find(intfSt => intfSt.device === device)
        if (interfaceStatusResult) {
          const { javaClass, interfaceId, ...rest } = interfaceStatusResult
          Object.assign(this.settings, rest) // Update reactive object
          console.log('javaClass : ', javaClass)
          console.log('interfaceId : ', interfaceId)
        }
        cb()
      },
      /** returns box Wi-Fi channels */
      async onGetWifiChannels(countryCode, cb) {
        if (countryCode === '') {
          countryCode = await window.rpc.networkManager.getWirelessRegulatoryCountryCode(this.interfaces.device)
        }
        const response = (await window.rpc.networkManager.getWirelessChannels(this.interfaces.device, countryCode)) || [
          { frequency: this.$t('no_channel_match'), channel: -1 },
        ]
        cb(response ?? null)
      },

      async onGetCountryItems(device, cb) {
        const response = await window.rpc.networkManager.getWirelessValidRegulatoryCountryCodes(device)
        cb(response ?? null)
      },

      async onGetWirelessChannels(device, newValue, cb) {
        const response = await window.rpc.networkManager.getWirelessChannels(device, newValue)
        cb(response ?? null)
      },

      async onWirelessRegulatoryCompliant(device, cb) {
        const response = await window.rpc.networkManager.isWirelessRegulatoryCompliant(device)
        cb(response ?? null)
      },

      async onSave(newSettings, validate) {
        try {
          const isValid = await validate()
          if (!isValid) return
          this.isSaving = true
          this.$store.commit('SET_LOADER', true)
          if (Util.isDestroyed(this, newSettings)) {
            this.isSaving = false
            this.$store.commit('SET_LOADER', false)
            return
          }
          const cb = this.$store.state.setEditCallback
          if (cb) cb()
          await this.$store.dispatch('settings/setInterface', newSettings)
          this.isSaving = false
          this.$store.commit('SET_LOADER', false)
          this.$router.push('/settings/network/interfaces')
        } catch (ex) {
          this.isSaving = false
          this.$store.commit('SET_LOADER', false)
          Util.handleException(ex)
        }
      },

      /**
       * Removes the interface
       * - show a confirm dialog
       */
      onDelete() {
        this.deleteInterfaceHandler(this.settings, () => {
          this.$router.push('/settings/network/interfaces')
        })
      },
      isBridgedInterface() {
        const currentDevice = this.device
        let isBridgeInterface = false
        let currentInterfaceId = ''
        for (const interfaceItem of this.interfaces) {
          if (interfaceItem.device === currentDevice) {
            currentInterfaceId = interfaceItem.interfaceId
            break
          }
        }
        for (const interfaceItem of this.interfaces) {
          if (interfaceItem.type === 'BRIDGE') {
            const matchedInterface = interfaceItem.bridgedInterfaces.includes(currentInterfaceId)
            if (matchedInterface) {
              isBridgeInterface = true
              this.isBridged = true
              this.bridgedInterfaceName = interfaceItem.device
              break
            }
          }
        }
        return isBridgeInterface
      },
    },
  }
</script>
