<template>
  <settings-dns ref="dns" :settings="dnsSettings">
    <template #actions="{ newSettings, isDirty }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings)">{{ $t('save') }}</u-btn>
    </template>
  </settings-dns>
</template>
<script>
  import { SettingsDns } from 'vuntangle'
  import transform from '@/util/transform'

  export default {
    components: { SettingsDns },

    computed: {
      dnsSettings: () => transform.dns.get(),
    },

    methods: {
      async onSaveSettings(newDnsSettings) {
        await this.$store.dispatch('settings/saveNetworkSettings', transform.dns.set(newDnsSettings))
      },
    },
  }
</script>
