<template>
  <appliance-system :system-settings="systemSettings" :support-access-enabled="true" @save-web-ports="onSaveWebPorts" />
</template>
<script>
  import { ApplianceSystem } from 'vuntangle'

  export default {
    components: { ApplianceSystem },

    computed: {
      systemSettings: ({ $store }) => $store.getters['settings/systemSetting'],
    },
    created() {
      this.$store.dispatch('settings/getSystemSettings', true) // update current system setting from store store
    },
    methods: {
      async onSaveWebPorts({ system, cb }) {
        this.$store.commit('SET_LOADER', true)
        const response = await this.$store.dispatch('settings/setSystemSettings', system)
        cb(response.success)
        this.$store.commit('SET_LOADER', false)
      },
    },
  }
</script>
