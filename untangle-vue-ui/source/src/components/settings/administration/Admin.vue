<template>
  <!-- Main administration component wrapping AdministrationAdmin from vuntangle -->
  <settings-admin :settings="settings">
    <template #actions="{ newSettings, isDirty, validate }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings, validate)">{{
        $t('save')
      }}</u-btn>
    </template>
  </settings-admin>
</template>

<script>
  import { SettingsAdmin } from 'vuntangle'
  import settingsMixin from '../settingsMixin'

  export default {
    components: { SettingsAdmin },
    mixins: [settingsMixin],

    computed: {
      /**
       * Retrieves admin settings from the Vuex store.
       * @returns {Object} Admin settings object.
       */
      adminSettings: ({ $store }) => $store.getters['settings/adminSetting'],
      /**
       * Retrieves system settings from the Vuex store.
       * @returns {Object} System settings object.
       */
      systemSettings: ({ $store }) => $store.getters['settings/systemSetting'],
      /**
       * Combines admin and system settings into a single object.
       * @returns {Object} Combined settings object.
       */
      settings() {
        return { ...this.adminSettings, system: this.systemSettings }
      },
    },

    /** Fetches initial admin and system settings. */
    created() {
      this.fetchAdminSettings(false)
      this.fetchSystemSettings(false)
    },

    methods: {
      /* Fetches admin settings from the backend and updates the store. */
      async fetchAdminSettings(refetch) {
        await this.$store.dispatch('settings/getAdminSettings', refetch)
      },

      /* Fetches system settings from the backend and updates the store. */
      async fetchSystemSettings(refetch) {
        await this.$store.dispatch('settings/getSystemSettings', refetch)
      },

      /**
       * Handles saving of new administration and system settings.
       * Validates settings, identifies changes, and dispatches actions to update the store.
       * @param {Object} newSettings - The new combined settings object, where system settings are under the 'system' key.
       * @param {Function} validate - Validation function for the settings form.
       */
      async onSaveSettings(newSettings, validate) {
        if (!(await validate())) return

        const { system: newSystemSettings, ...newAdminSettings } = newSettings
        const changes = []

        if (!this.isEqual(newAdminSettings, this.adminSettings)) {
          changes.push(this.$store.dispatch('settings/setAdminSettings', newAdminSettings))
        }

        if (!this.isEqual(newSystemSettings, this.systemSettings)) {
          changes.push(this.$store.dispatch('settings/setSystemSettings', newSystemSettings))
        }

        if (!changes.length) return

        this.$store.commit('SET_LOADER', true)
        try {
          await Promise.all(changes)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
      /**
       * Compares two objects for equality by converting them to JSON strings.
       * @returns {boolean} True if the objects are equal, false otherwise.
       */
      isEqual(obj1, obj2) {
        return JSON.stringify(obj1) === JSON.stringify(obj2)
      },

      /**
       * Optional hook triggered on browser refresh.
       * Fetches updated Admin settings and updates the store.
       */
      onBrowserRefresh() {
        this.fetchAdminSettings(true)
        this.fetchSystemSettings(true)
      },
    },
  }
</script>
