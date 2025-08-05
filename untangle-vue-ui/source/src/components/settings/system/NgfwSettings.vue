<template>
  <appliance-system :system-settings="systemSettings" :support-access-enabled="true" @save-web-ports="onSaveWebPorts" />
</template>
<script>
  import { ApplianceSystem } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  // import appliances from '@/plugins/ut/ut-appliances'
  // import api from '@/plugins/ut/ut-api'
  // import util from '@/plugins/ut/ut-util'

  export default {
    components: { ApplianceSystem },
    mixins: [settingsMixin],

    computed: {
      systemSettings: ({ $store }) => $store.getters['settings/systemSetting'],
    },
    created() {
      this.$store.dispatch('settings/getSystemSettings') // update current system setting from store store
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

/** BoxSettings is coming from settingsMixin which is getting an full setting of appliances - need to impliment,
currently assign it as networkSetting (for avioding errors) */
