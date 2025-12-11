<template>
  <email
    :mail-sender-settings="mailSender"
    :company-name="companyName"
    @save-email-server-settings="onSaveEmailServerSettings"
    @refresh-settings="onRefreshSettings"
  />
</template>
<script>
  import { Email } from 'vuntangle'

  /**
   * Wrapper component for email settings.
   * Fetches and saves email server settings using Vuex.
   */
  export default {
    components: { Email },

    computed: {
      /**
       * Mail sender settings from Vuex store.
       * @returns {object}
       */
      mailSender: ({ $store }) => $store.getters['config/mailSender'],
      /**
       * SMTP settings from Vuex store.
       * @returns {object}
       */
      smtpSettings: ({ $store }) => $store.getters['apps/getSettings']('smtp'),
      /**
       * Expert mode status from Vuex store.
       * @returns {boolean}
       */
      isExpertMode: ({ $store }) => $store.getters['config/isExpertMode'],
      /**
       * Company name from global rpc object.
       * @returns {string|null}
       */
      companyName() {
        return window?.rpc?.companyName || null
      },
    },
    /**
     * Fetches mail sender settings when the component is created.
     */
    created() {
      this.$store.dispatch('config/getMailSender', true)
    },

    methods: {
      /**
       * Saves email server settings.
       * @param {object} emailServerSettings - The email server settings to save.
       * @param {function} cb - The callback function.
       */
      onSaveEmailServerSettings({ emailServerSettings, cb }) {
        this.$store.commit('SET_LOADER', true)
        this.$store
          .dispatch('config/setMailSender', emailServerSettings)
          // prettier-ignore
          .then(response => {
            cb(response)
          })
          .finally(() => {
            this.$store.commit('SET_LOADER', false)
          })
      },

      /**
       * Refreshes mail sender settings.
       */
      onRefreshSettings() {
        this.$store.commit('SET_LOADER', true)
        this.$store.dispatch('config/getMailSender', true).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
      },
    },
  }
</script>
