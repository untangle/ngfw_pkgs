<template>
  <settings-dhcp :settings="dhcpSettings" :leases="leases" :fetching="fetching" @fetch-leases="onFetchLeases">
    <template #actions="{ newSettings, isDirty }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings)">{{ $t('save') }}</u-btn>
    </template>
  </settings-dhcp>
</template>
<script>
  import { SettingsDhcp } from 'vuntangle'
  import transform from '@/util/transform'

  export default {
    components: { SettingsDhcp },

    data() {
      return {
        leases: [],
        fetching: false,
      }
    },

    computed: {
      dhcpSettings: () => transform.dhcp.get(),
    },

    methods: {
      async onFetchLeases() {
        this.fetching = true
        this.leases = await window.rpc.networkManager.getStatus('DHCP_LEASES', null)
        this.fetching = false
        this.leases = []
      },

      async onSaveSettings(newDhcpSettings) {
        await this.$store.dispatch('settings/saveNetworkSettings', transform.dhcp.set(newDhcpSettings))
      },
    },
  }
</script>
