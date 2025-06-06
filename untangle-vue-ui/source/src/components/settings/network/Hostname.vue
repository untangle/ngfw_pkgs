<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-2`">
    <settings-hostname ref="component" :settings="settings" :new-settings="newSettings" :is-saving="isSaving">
      <template #actions="{ newSettings, isDirty, validate }">
        <u-btn :min-width="null" :disabled="!isDirty" @click="onSave(validate, newSettings)">
          {{ $t('save') }}
        </u-btn>
      </template>
    </settings-hostname>
  </v-container>
</template>
<script>
  import SettingsHostname from './SettingHostname.vue'
  import Util from '@/util/setupUtil'
  export default {
    components: {
      SettingsHostname,
    },
    data() {
      return {
        rpc: null,
        settings: null,
        newSettings: null,
        isSaving: false,
      }
    },
    computed: {
      $newSettings: () => this.newSettings,
    },
    created() {
      this.rpc = Util.setRpcJsonrpc('admin')
      this.settings = this.rpc.networkManager.getNetworkSettings()
    },
    methods: {
      async onSave(validate, newSettings) {
        try {
          const isValid = await validate()
          if (!isValid) return
          this.isSaving = true
          if (newSettings.dynamicDnsServiceName && newSettings.dynamicDnsServiceName.value) {
            newSettings.dynamicDnsServiceName = newSettings.dynamicDnsServiceName.value
          }
          await this.$store.dispatch('settings/setNetworkSettings', newSettings)
          if (this.$store.state.settings.editCallback) {
            this.$store.state.settings.editCallback()
          }
          this.settings = this.rpc.networkManager.getNetworkSettings()
          this.isSaving = false
        } catch (error) {
          Util.handleException(error)
        }
      },
    },
  }
</script>
