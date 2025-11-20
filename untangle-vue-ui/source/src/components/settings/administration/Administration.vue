<template>
  <!-- Main administration component wrapping AdministrationAdmin from vuntangle -->
  <AdministrationAdmin :settings="adminSettings" :system-settings="systemSettings">
    <template #actions="{ newSettings, newSystemSettings, isDirty, validate }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings, newSystemSettings, validate)">{{
        $t('save')
      }}</u-btn>
    </template>
  </AdministrationAdmin>
</template>

<script>
  import { AdministrationAdmin } from 'vuntangle'

  export default {
    components: { AdministrationAdmin },

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
       * @param {Object} newSettings - The new admin settings.
       * @param {Object} newSystemSettings - The new system settings.
       * @param {Function} validate - Validation function for the settings form.
       */
      async onSaveSettings(newSettings, newSystemSettings, validate) {
        const isValid = await validate()
        if (!isValid) return

        const changes = []

        // Check if admin settings have changed and push update action if they have
        if (!this.isEqual(newSettings, this.adminSettings)) {
          changes.push(this.$store.dispatch('settings/setAdminSettings', newSettings))
        }

        // Check if system settings have changed and push update action if they have
        if (!this.isEqual(newSystemSettings, this.systemSettings)) {
          changes.push(this.$store.dispatch('settings/setSystemSettings', newSystemSettings))
        }

        // If no changes were detected, do nothing
        if (changes.length === 0) return

        this.$store.commit('SET_LOADER', true)
        await Promise.all(changes).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
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
