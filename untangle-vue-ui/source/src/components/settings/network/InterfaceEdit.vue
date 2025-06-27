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
      :features="features"
      @renew-dhcp="onRenewDhcp"
      @delete="onDelete"
      @get-status-wan-test="onGetStatusWanTest"
      @get-wifi-channels="onGetWifiChannels"
      @get-wifi-mode-list="onGetWifiModeList"
    >
      <!-- <template #no-license>
        <no-license v-if="!canAddInterface" class="mt-2">
          <template #actions>
            <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
            <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
              {{ $t('manage_licenses') }}
              <v-icon right> mdi-open-in-new </v-icon>
            </u-btn>
          </template>
</no-license>
</template> -->
      <!-- <template #bridged-interface>
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
      </template> -->
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
  // import cloneDeep from 'lodash/cloneDeep'
  import { SettingsInterface } from 'vuntangle'
  import Util from '../../../util/setupUtil'
  import dummyJson from './MockData.json'
  import dummyInterfaces from './MockDataAll.json'
  import interfaceMixin from './interfaceMixin'
  import api from '@/plugins/api'

  export default {
    components: {
      SettingsInterface,
    },
    mixins: [interfaceMixin],
    data: () => ({
      status: null,
      canAddInterface: true,
      manageLicenseUri: undefined,
      isBridged: undefined,
      bridgedInterfaceName: undefined,
      isSaving: false,
      // always true for NGFW
      features: {},
      interfaces: dummyJson,
      device: dummyJson[0].device,
    }),
    computed: {
      settings() {
        return this.interfaces.find(item => item.device === this.device)
      },

      // device: ({ $route }) => $route.params.device,
      // device() {
      //   const intf = this.$store.getters['settings/interfaces']?.[0]
      //   return intf?.systemDev || intf?.symbolicDev || null
      // },
      type: ({ $route }) => $route.params.type,
      // interfaces: ({ $store }) => $store.getters['settings/interfaces'],
      // settings: ({ $store, device }) => $store.getters['settings/interface'](device),
    },
    async mounted() {
      await this.setFeatures()
      this.isBridgedInterface()
      // Call getStatus conditionally only if not adding a new interface
      if (this.device) {
        // this.status = await this.getInterfaceStatus(this.device)
        this.status = dummyInterfaces[1]
      }
      // set the help context for this device type (e.g. interfaces_wwan)
      // uncomment below line once type is assigned from backend
      this.$store.commit('SET_HELP_CONTEXT', `interfaces_${(this.type || this.settings?.type).toLowerCase()}`)
    },
    methods: {
      setFeatures() {
        this.features.hasVrrp = true // for vrrp tab
        this.features.hasPppoe = true // for pppoe radio button
        this.features.hasBridged = true // for menu item
        this.features.hasGatewayMetric = this.settings.wan // this.intf.isWan // for v4StaticGateway show if isWan true
        this.features.hasNatIngress = true
      },

      getInterfaceStatus(device) {
        return new Promise((resolve, reject) => {
          window.rpc.networkManager.getInterfaceStatus((result, error) => {
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

      async onGetStatusWanTest(l3device, cb) {
        const response = await api.get(`/api/status/wantest/${l3device}`)
        cb(response)
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

      async onSave(newSettings, validate) {
        try {
          const isValid = await validate()
          if (!isValid) return

          this.isSaving = true
          this.$store.commit('SET_LOADER', true)

          // const intfToSave = this.$refs.component.settingsCopy
          // if (Util.isDestroyed(this, intfToSave)) {
          if (Util.isDestroyed(this, newSettings)) {
            this.isSaving = false
            this.$store.commit('SET_LOADER', false)
            return
          }
          const cb = this.$store.state.setEditCallback
          if (cb) cb()

          // await this.$store.dispatch('settings/setInterface', intfToSave)
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
