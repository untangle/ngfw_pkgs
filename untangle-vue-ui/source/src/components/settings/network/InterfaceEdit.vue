<template>
  <v-container>
    <settings-interface
      ref="component"
      :settings="settings"
      :is-saving="isSaving"
      :interfaces="interfaces"
      :type="type"
      :disabled="!canAddInterface && settings.type !== 'WIFI'"
      :status="status"
      :ping-analyzers="pingAnalyzers"
      :features="features"
      @renew-dhcp="onRenewDhcp"
      @manage-status-analyzers="onManageStatusAnalyzers"
      @delete="onDelete"
      @get-all-interface-status="onGetAllInterfaceStatus"
      @get-status-hardware="onGetStatusHardware"
      @get-status-wan-test="onGetStatusWanTest"
      @get-wifi-channels="onGetWifiChannels"
      @get-wifi-mode-list="onGetWifiModeList"
      @get-status-wwan="onGetStatusWwan"
      @get-wireguard-publickey="onGetWireguardPublicKey"
      @get-wireguard-keypair="onGetWireguardKeypair"
      @get-wireguard-address-check="onWireguardAddressCheck"
      @get-device-status="onGetDeviceStatus"
      @get-wireguard-random-address="onGenerateWireguardRandomAddress"
    >
      <template #no-license>
        <no-license v-if="!canAddInterface" class="mt-2">
          {{ getVpnInterfaceMessage() }}
          <template #actions>
            <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
            <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
              {{ $t('manage_licenses') }}
              <v-icon right> mdi-open-in-new </v-icon>
            </u-btn>
          </template>
        </no-license>
      </template>
      <template #bridged-interface>
        <v-alert v-if="isBridged && canAddInterface && settings.type !== 'WIFI'" text color="primary">
          <div class="d-flex align-left ml-1">
            <strong>
              <slot>
                <v-icon color="primary" class="mr-4">mdi-information</v-icon>
                <span>{{ $t('bridged_interface_info') }} {{ bridgedInterfaceName }}</span>
              </slot>
            </strong>
            <v-spacer />
            <slot name="actions"></slot>
          </div>
        </v-alert>
      </template>
      <template #actions="{ newSettings, isDirty, validate }">
        <u-btn to="/settings/network/interfaces" class="mr-2">{{ $t('back_to_list') }}</u-btn>
        <u-btn :min-width="null" :disabled="!isDirty || !canAddInterface" @click="onSave(newSettings, validate)">
          {{ $t('save') }}
        </u-btn>
      </template>
    </settings-interface>
  </v-container>
</template>
<script>
  import cloneDeep from 'lodash/cloneDeep'
  import { VAlert, VSpacer } from 'vuetify/lib'
  import { NoLicense, SettingsInterface } from 'vuntangle'
  import interfaceMixin from './interfaceMixin'
  import api from '@/plugins/api'
  import http from '@/plugins/http'
  import uris from '@/util/uris'

  import util from '@/util/util'

  export default {
    components: {
      VAlert,
      VSpacer,
      NoLicense,
      SettingsInterface,
    },
    mixins: [interfaceMixin],
    data: () => ({
      status: null,
      canAddInterface: true, // MFW-2454 : limits ability to create VPN interfaces on un-licensed appliance
      manageLicenseUri: undefined,
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
      pingAnalyzers: ({ $store }) => $store.getters['settings/settings'].stats?.pingAnalyzers,
    },
    async mounted() {
      await this.setFeatures()
      this.isBridgedInterface()
      // Call getStatus conditionally only if not adding a new interface
      if (this.device) {
        await this.getStatus()
      }
      this.setLicenseAndLicenseUri()
      // set the help context for this device type (e.g. interfaces_wwan)
      // <! -- TODO uncommnet below
      // this.$store.commit('SET_HELP_CONTEXT', `interfaces_${(this.type || this.settings?.type).toLowerCase()}`)
    },
    methods: {
      setFeatures() {
        const platform = this.$store.getters['hardware/platform']
        this.features.hasVrrp = platform === 'MFW_EOS'
        this.features.hasPppoe = platform === 'OPENWRT'
        this.features.hasBridged = platform === 'MFW_EOS'
      },
      getVpnInterfaceMessage() {
        switch (this.type?.toLowerCase()) {
          case 'openvpn':
            return this.$t('not_licensed_interface', [this.$t('open_vpn')])
          case 'wireguard':
            return this.$t('not_licensed_interface', [this.$t('wireguard')])
          case 'ipsec':
            return this.$t('not_licensed_interface', [this.$t('ipsec_tunnel')])
        }
        return ''
      },
      async setLicenseAndLicenseUri() {
        this.manageLicenseUri = await uris.translate(uris.list.subscriptions)

        // MFW-2454: VPN Interfaces can only be added on licensed appliance
        if (['openvpn', 'ipsec', 'wireguard'].includes(this.type)) {
          const response = await api.get('/api/status/license')
          this.canAddInterface = response?.list?.length > 0 || false
        } else {
          this.canAddInterface = true
        }
      },

      // get the interface status
      async getStatus() {
        const response = await api.get(`/api/status/interfaces/${this.device}`)
        if (response && Array.isArray(response)) {
          this.status = response[0]
        }
      },

      // renews DHCP and refetches status
      async onRenewDhcp(device, cb) {
        await api.post(`/api/renewdhcp/${device}`)
        await this.getStatus()
        cb()
      },

      // redirects to manage analyzers route
      onManageStatusAnalyzers() {
        this.$router.push('/settings/network/status-analyzers')
      },

      // returns all interface statuses
      async onGetAllInterfaceStatus(cb) {
        const response = await api.get('/api/status/interfaces/all')
        cb(response)
      },

      /** returns box status hardware info */
      async onGetStatusHardware(cb) {
        const response = await api.get('/api/status/hardware')
        cb(response)
      },

      async onGetStatusWanTest(l3device, cb) {
        const response = await api.get(`/api/status/wantest/${l3device}`)
        cb(response)
      },

      /** returns box wwan status */
      async onGetStatusWwan(device, cb) {
        const response = await http.get(`/api/status/wwan/${device}`)
        cb(response.data ?? null)
      },

      /** returns box Wi-Fi channels */
      async onGetWifiChannels(device, cb) {
        const response = await api.get(`/api/status/wifichannels/${device}`)
        cb(response ?? null)
      },

      /** returns box Wi-Fi mode list */
      async onGetWifiModeList(device, cb) {
        try {
          const response = await api.get(`/api/status/wifimodelist/${device}`)
          cb(response ?? null)
        } catch (ex) {
          cb(null)
        }
      },

      /** returns wireguard public key */
      async onGetWireguardPublicKey(privateKey, cb) {
        try {
          const response = await http.post('/api/wireguard/publickey', { privateKey })
          cb(response.data ?? null)
        } catch (ex) {
          cb(null)
        }
      },

      /** returns wireguard keypair */
      async onGetWireguardKeypair(cb) {
        try {
          const response = await http.get('/api/wireguard/keypair')
          cb(response.data ?? null)
        } catch (ex) {
          cb(null)
        }
      },

      /** returns available random address for wireguard */
      async onGenerateWireguardRandomAddress(cb) {
        try {
          const response = await http.post('/api/netspace/request', {
            ipVersion: '4',
            hostID: '1',
            networkSize: '24',
          })
          cb(response.data ?? null)
        } catch (ex) {
          cb(null)
        }
      },

      /** returns wireguard address check */
      async onWireguardAddressCheck(value, cb) {
        const response = await util.addressChecker(value + '/24')
        cb(response ?? null)
      },

      /** returns device status */
      async onGetDeviceStatus(device, cb) {
        try {
          const response = await api.get(`/api/status/interfaces/${device}`)
          cb(response ?? null)
        } catch (ex) {
          cb(null)
        }
      },

      async onSave(newSettings, validate) {
        const isValid = await validate()
        if (!isValid) return
        this.isSaving = true
        // push changes via store actions
        this.$store.commit('SET_LOADER', true)
        // disable IPsec interfaces bound to disabled wan interface
        const interfaces = this.disableIpsecInterfacesBoundToWan(newSettings)
        let resultIntf = { success: false }
        if (interfaces.length === 0) {
          // Save interface settings by updating the current interface- newSettings
          resultIntf = await this.$store.dispatch('settings/setInterface', newSettings)
        } else {
          // Save all interfaces settings that the current interface
          // plus some other modified (disabled) IPSec interfaces
          resultIntf = await this.$store.dispatch('settings/setInterfaces', interfaces)
        }

        // save policies if changed (forced enabled)
        let resultWan = { success: true }
        const updatedWan = this.validateIpsecPoliciesAndRules(newSettings)
        if (updatedWan) {
          resultWan = await this.$store.dispatch('settings/setWan', { wan: updatedWan })
        }

        this.$store.commit('SET_LOADER', false)
        this.isSaving = false
        if (resultIntf.success && resultWan.success) {
          this.$vuntangle.toast.add(this.$t('saved_successfully', [this.$t('interface')]))
        } else {
          this.$vuntangle.toast.add(this.$t('rolled_back_settings', [resultIntf.message || resultWan.message]))
        }

        // return to main interfaces screen on success or error toast to avoid blank screen
        this.$router.push('/settings/network/interfaces')
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

      /**
       * When disabling a WAN interface, disable IPSec interfaces that are bound to this interface.
       * @returns {Array} - the updated interfaces array.
       */
      disableIpsecInterfacesBoundToWan(newSettings) {
        if (newSettings.enabled || newSettings.type !== 'NIC' || !newSettings.wan) return []
        const wanId = newSettings.interfaceId
        const interfaces = cloneDeep(this.interfaces)
        for (let i = 0; i < interfaces.length; i++) {
          if (interfaces[i].boundInterfaceId === wanId) {
            interfaces[i].enabled = false
          } else if (interfaces[i].interfaceId === wanId) {
            interfaces[i] = newSettings
          }
        }
        return interfaces
      },

      /**
       * when enabling a disabled IPsec interface also enable policies related to it
       * @returns {Array|Boolean} - the updated policies array or false
       */
      validateIpsecPoliciesAndRules(newSettings) {
        if (!newSettings.enabled || newSettings.type !== 'IPSEC') return false
        const wanCopy = cloneDeep(this.$store.getters['settings/settings']?.wan)
        if (!wanCopy) return false

        const policies = wanCopy.policies
        const rules = wanCopy.policy_chains.find(chain => chain.name === 'user-wan-rules').rules
        const affectedPoliciesIds = []

        policies.forEach(policy => {
          policy.interfaces.forEach(intf => {
            // find policies related to current interface
            if (intf.interfaceId === newSettings.interfaceId && !policy.enabled) {
              affectedPoliciesIds.push(policy.policyId)
              policy.enabled = newSettings.enabled
            }
          })
        })
        rules.forEach(rule => {
          // check rule action policy in affected policies
          if (affectedPoliciesIds.includes(rule.action.policy) && !rule.enabled) {
            rule.enabled = true
          }
        })

        if (affectedPoliciesIds.length < 0) return false
        return wanCopy
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
