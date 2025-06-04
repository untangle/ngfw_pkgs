<template>
  <v-container>
    <settings-interface
      ref="component"
      :settings="settings"
      :is-saving="isSaving"
      :intf="intf"
      :interfaces="interfaces"
      :interface-statuses="interfaceStatuses"
      :status="status"
      @delete="onDelete"
    >
      <template #actions="{ isDirty, validate }">
        <u-btn to="/settings/network/interfaces" class="mr-2">{{ $t('back_to_list') }}</u-btn>
        <u-btn :min-width="null" :disabled="!isDirty" @click="onSave(validate)">
          {{ $t('save') }}
        </u-btn>
      </template>
    </settings-interface>
  </v-container>
</template>
<script>
  import SettingsInterface from '../network/SettingsInterface'
  import Util from '../../../util/setupUtil'
  import interfaceMixin from './interfaceMixin'

  export default {
    components: {
      SettingsInterface,
    },
    mixins: [interfaceMixin],
    data: () => ({
      intf: null,
      status: null,
      manageLicenseUri: undefined,
      isBridged: undefined,
      bridgedInterfaceName: undefined,
      isSaving: false,
    }),
    computed: {
      device: ({ $route }) => $route.params.device,
      $intf: () => this.intf,
      // type: ({ $route }) => $route.params.type,
      interfaces: ({ $store }) => $store.getters['settings/interfaces'],
      settings: ({ $store }) => $store.getters['settings/settings'],
      interfaceStatuses: ({ $store }) => $store.getters['settings/interfaceStatuses'],
    },
    created() {
      this.intf = this.device ? this.interfaces.find(i => i.systemDev === this.device) : {}
    },
    methods: {
      async onSave(validate) {
        try {
          const isValid = await validate()
          if (!isValid) return
          this.isSaving = true
          this.$store.commit('SET_LOADER', true)
          if (Util.isDestroyed(this, this.intf)) {
            return
          }
          if (this.$store.state.settings.editCallback) {
            this.$store.state.settings.editCallback()
          }
          // Save interface settings by updating the current interface
          await this.$store.dispatch('settings/setInterface', this.intf)
          this.$store.commit('SET_LOADER', false)
          this.isSaving = false
          // return to main interfaces screen on success or error toast to avoid blank screen
          this.$router.push('/settings/network/interfaces')
        } catch (ex) {
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
    },
  }
</script>
