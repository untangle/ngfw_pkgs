<template>
  <v-container fluid class="d-flex flex-column flex-grow-1">
    <about
      :server-data="serverData"
      :license-headers="licenseHeaders"
      :licenses-data="licensesData"
      @refresh-licenses="loadLicenses"
    >
      <template #actions>
        <div v-if="legalUrl" class="d-flex">
          <u-btn :href="legalUrl" target="_blank">
            {{ $t('view_license') }}
            <v-icon right> mdi-open-in-new </v-icon>
          </u-btn>
        </div>
      </template>
    </about>
  </v-container>
</template>

<script>
  import { About } from 'vuntangle'
  import Rpc from '../../../util/Rpc'
  import util from '../../../util/util'
  import Util from '../../../util/setupUtil'

  export default {
    components: { About },

    data() {
      return {
        serverData: [],
        licensesData: [],
        legalUrl: undefined,
      }
    },

    computed: {
      // Defines the headers for the licenses table
      licenseHeaders() {
        return [
          { key: 'displayName', label: 'name' },
          { key: 'currentName', label: 'ac_applications' },
          { key: 'UID', label: 'uid_name' },
          { key: 'start', label: 'start' },
          { key: 'end', label: 'end' },
          { key: 'seats', label: 'seats' },
          { key: 'valid', label: 'valid' },
          { key: 'status', label: 'status' },
        ]
      },
    },

    async created() {
      await this.getServerData()
      await this.loadLicenses()
      await this.getLegalUrl()
    },

    // Component methods
    methods: {
      // Fetches server information from various RPC endpoints
      async getServerData() {
        this.$store.commit('SET_LOADER', true) // Activate loader
        try {
          const safe = fn => Promise.resolve().then(fn)
          const rpc = window.rpc

          // Execute multiple RPC calls concurrently to get server data
          const results = await Promise.allSettled([
            safe(() => rpc.adminManager.getKernelVersion()), // Kernel version
            safe(() => rpc.adminManager.getModificationState()), // Modification state
            safe(() => rpc.adminManager.getRebootCount()), // Reboot count
            safe(() => rpc.hostTable.getCurrentActiveSize()), // Current active device count
            safe(() => rpc.hostTable.getMaxActiveSize()), // Max active device count since reboot
            safe(() => rpc.fullVersionAndRevision), // Full version and revision
            safe(() => rpc.serverUID), // Server UID
            safe(() => rpc.serverSerialnumber), // Server serial number
            safe(() => rpc.regionName), // Region name
          ])

          const val = r => (r.status === 'fulfilled' ? r.value : undefined)
          const [kernel, history, reboots, currentActive, maxActive, build, uid, serial, region] = results.map(val)

          // Initialize data array with UID
          const data = []
          if (uid != null) data.push({ name: 'uid_name', value: uid })
          // Add serial number if available
          if (serial) data.push({ name: 'serial_number', value: serial })

          // Fetch account info if UID is valid
          if (uid?.length === 19) {
            try {
              const account = await util.fetchAccountInfo(uid)
              if (account?.account) data.push({ name: 'account', value: account.account })
            } catch {
              // external store unreachable
            }
          }

          // Add remaining server data to the array
          const fields = [
            ['build', build],
            ['kernel', kernel],
            ['region', region],
            ['history', history],
            ['reboots', reboots],
            ['current_active_device_count', currentActive],
            ['highest_active_device_count_since_reboot', maxActive],
          ]
          for (const [name, value] of fields) {
            if (value != null) data.push({ name, value })
          }

          // Update component's serverData
          this.serverData = data
        } catch (err) {
          Util.handleException(err)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      // Loads license data, refreshing them if necessary
      async loadLicenses() {
        this.$store.commit('SET_LOADER', true)
        try {
          await util.reloadLicenses()
          // Fetch licenses from the RPC endpoint
          const res = await Rpc.asyncData('rpc.UvmContext.licenseManager.getLicenses')
          this.licensesData = res.list || []
        } catch (err) {
          Util.handleException(err)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      // Fetches the legal URL from the RPC endpoint
      async getLegalUrl() {
        try {
          this.legalUrl = await Rpc.directData('rpc.UvmContext.getLegalUrl')
        } catch (err) {
          Util.handleException(err)
        }
      },
    },
  }
</script>
