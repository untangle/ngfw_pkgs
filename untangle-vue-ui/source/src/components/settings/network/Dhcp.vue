<template>
  <settings-dhcp :settings="dhcpSettings" :leases="leases" :fetching="fetching" @fetch-leases="onFetchLeases">
    <template #actions="{ newSettings, isDirty, validate }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings, validate)">{{
        $t('save')
      }}</u-btn>
    </template>
  </settings-dhcp>
</template>
<script>
  import { SettingsDhcp } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import Rpc from '@/util/Rpc'
  import Util from '@/util/setupUtil'

  export default {
    components: { SettingsDhcp },
    mixins: [settingsMixin],

    data() {
      return {
        leases: [],
        fetching: false,
      }
    },

    computed: {
      dhcpSettings: ({ $store }) => $store.getters['settings/networkSetting'],
    },

    created() {
      this.onFetchLeases()
      this.fetchSettings(false)
    },

    methods: {
      /**
       * Fetches the settings and updates the store.
       * If refetch is true, it forces a re-fetch of the settings.
       * @param {boolean} refetch - Whether to force a re-fetch of the settings.
       */
      async fetchSettings(refetch) {
        await this.$store.dispatch('settings/getNetworkSettings', refetch)
      },

      /**
       * @description Fetches DHCP leases from the server and updates the local leases array.
       * @async
       * @function onFetchLeases
       * @returns {Promise<void>}
       */
      async onFetchLeases() {
        // Set the fetching flag to true to indicate that the data is being fetched.
        this.fetching = true
        try {
          // Call the RPC method to get the DHCP leases data as a string.
          const result = await Rpc.asyncData('rpc.networkManager.getStatus', 'DHCP_LEASES', null)
          // Split the string result into an array of lines.
          const lines = result.split('\n')
          const leases = []

          for (let i = 0; i < lines.length; i++) {
            if (!lines[i]) continue
            const lineparts = lines[i].split(/\s+/)
            if (lineparts.length === 5) {
              // Push a new object containing the DHCP lease information to the leases array.
              leases.push({
                leaseExpiration: lineparts[0], // The date of the DHCP lease.
                macAddress: lineparts[1], // The MAC address of the device with the lease.
                ipAddr: lineparts[2], // The IP address assigned to the device.
                hostName: lineparts[3], // The hostname of the device.
                clientId: lineparts[4], // The client ID of the device.
              })
            }
          }

          this.leases = leases
        } catch (err) {
          Util.handleException(err)
          this.leases = []
        } finally {
          this.fetching = false
        }
      },

      /**
       * In onSaveSettings, we validate the DHCP Leases value.
       * For this, validate() is used as a prop.
       */
      async onSaveSettings(newDhcpSettings, validate) {
        const isValid = await validate()
        if (!isValid) return
        this.$store.commit('SET_LOADER', true)
        await Promise.all([this.$store.dispatch('settings/setNetworkSettingV2', newDhcpSettings)]).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
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
