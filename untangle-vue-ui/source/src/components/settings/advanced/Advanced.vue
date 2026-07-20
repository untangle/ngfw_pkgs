<template>
  <settings-advanced
    ref="advanced"
    :is-expert-mode="isExpertMode"
    :settings="networkSettings"
    :network-status="networkStatus"
    :interfaces="interfaces"
    :interfacesfor-qos-rule="interfacesforQosRule"
    :qos-statistics="qosStatistics"
    @get-qos-statistics="getQosStatistics"
    @get-network-card-status="getNetworkCardStatus"
  >
    <template #actions="{ newSettings, isDirty, validate }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings, validate)">{{
        $t('save')
      }}</u-btn>
    </template>
  </settings-advanced>
</template>

<script>
  import { SettingsAdvanced } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import Rpc from '../../../util/Rpc'
  import Util from '../../../util/setupUtil'
  import util from '@/util/util'

  export default {
    components: { SettingsAdvanced },
    mixins: [settingsMixin],

    data() {
      return {
        networkStatus: [],
        qosStatistics: [],
      }
    },

    computed: {
      /* network settings from the store */
      networkSettings: ({ $store }) => $store.getters['config/networkSetting'],
      /* Gets the expert mode status from the settings store */
      isExpertMode: ({ $store }) => $store.getters['config/isExpertMode'],

      /* Get list of interfaces from the settings store */
      interfaces: ({ $store }) => $store.getters['config/interfaces'],
      /**
       * returns the interfaces for condition value from network settings
       * @param {Object} vm.networkSettings
       */
      interfacesforQosRule: ({ networkSettings }) => {
        return util.getInterfaceList(networkSettings, true, true)
      },
    },

    created() {
      this.fetchSettings(false)
    },

    methods: {
      /**
       * Fetches the settings and updates the store.
       * If refetch is true, it forces a re-fetch of the settings.
       * @param {boolean} refetch - Whether to force a re-fetch of the settings.
       */
      async fetchSettings(refetch) {
        await this.$store.dispatch('config/getNetworkSettings', refetch)
      },

      /**
       * Saves the advanced settings after validating them.
       * @param {Object} advancedSettings - The advanced settings to save.
       * @param {Function} validate - The validation function to call.
       */
      async onSaveSettings(advancedSettings, validate) {
        const isValid = await validate()
        if (!isValid) return

        this.$store.commit('SET_LOADER', true)
        await Promise.all([this.$store.dispatch('config/setNetworkSettingV2', advancedSettings)]).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
      },

      /**
       * Retrieves and processes the status of a selected network card.
       * It fetches the network device status using an RPC call, then formats and compares the status
       * with the selected network's configuration to identify any discrepancies.
       * @param {Object} selectedNetwork - The selected network object containing deviceName.
       */
      async getNetworkCardStatus(selectedNetwork) {
        if (!selectedNetwork?.deviceName) return

        this.$store.commit('SET_LOADER', true)

        try {
          const getStatus = await Rpc.asyncPromise('rpc.networkManager.getDeviceStatus')
          const result = await getStatus()
          const stat = result?.list?.find(s => s.deviceName === selectedNetwork.deviceName)

          if (!stat) return
          delete stat.javaClass

          // Define the fields to extract from the network status
          const fields = [
            { key: 'connected', label: 'connected' },
            { key: 'deviceName', label: 'device_name' },
            { key: 'duplex', label: 'duplex' },
            { key: 'eeeActive', label: 'eee_active' },
            { key: 'macAddress', label: 'mac_address' },
            { key: 'mbit', label: 'mbit' },
            { key: 'mtu', label: 'mtu' },
            { key: 'supportedLinkModes', label: 'supported_link_modes' },
            { key: 'vendor', label: 'vendor' },
          ]

          // Map the network status fields to the desired format
          this.networkStatus = fields.map(({ key, label }) => {
            let value = stat[key]
            let changed = false

            // Define rules to determine if a field has changed from the selected network
            const rules = {
              mtu: () => selectedNetwork.mtu !== 0 && stat.mtu !== selectedNetwork.mtu,
              duplex: () => {
                const duplex = selectedNetwork.duplex
                if (!duplex || duplex === 'AUTO') return false
                const [speed, type] = duplex.split('_', 2)
                const expectedMbit = speed?.substring(1)
                const expectedDuplex = type ? `${type}_DUPLEX` : null
                return (
                  (key === 'duplex' && expectedDuplex && stat.duplex !== expectedDuplex) ||
                  (key === 'mbit' && expectedMbit && String(stat.mbit) !== String(expectedMbit))
                )
              },
              mbit: () => {
                const duplex = selectedNetwork.duplex
                if (!duplex || duplex === 'AUTO') return false
                const [speed] = duplex.split('_', 2)
                const expectedMbit = speed?.substring(1)
                return expectedMbit && String(stat.mbit) !== String(expectedMbit)
              },
              eeeEnabled: () => String(selectedNetwork.energyEfficientEthernet) !== String(stat.eeeEnabled),
            }

            if (rules[key]) changed = rules[key]()

            if (typeof value === 'boolean') value = value ? 'true' : 'false'

            return {
              name: this.$t(label),
              value,
              changed,
            }
          })
        } catch (err) {
          this.networkStatus = []
          Util.handleException(err)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Retrieves and processes QoS statistics.
       * This function fetches QoS status via an RPC call, extracts a JSON string using a utility function,
       * parses it, and transforms the data for display.
       */
      async getQosStatistics() {
        this.$store.commit('SET_LOADER', true)

        try {
          const result = await Rpc.asyncData('rpc.networkManager.getStatus', 'QOS', null)
          if (!result) return

          const jsonString = util.extractJsonArrayString(result)
          if (!jsonString) {
            this.qosStatistics = []
            return
          }

          let list
          try {
            list = JSON.parse(jsonString)
          } catch (err) {
            this.qosStatistics = []
            return
          }

          this.qosStatistics = list.map(item => ({
            ...item,
            sent: parseInt(item.sent) || 0,
          }))
        } catch (err) {
          Util.handleException(err)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
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
