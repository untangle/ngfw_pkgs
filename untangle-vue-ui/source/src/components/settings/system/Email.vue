<template>
  <email
    :mail-sender-settings="mailSender"
    :company-name="companyName"
    :global-safe-list="globalSafeList"
    :user-safe-list="userSafeList"
    @email-test="sendTestEmail"
    @save-email-server-settings="onSaveEmailServerSettings"
    @refresh-settings="onRefreshSettings"
    @purge-user-safe-list="onPurgeUserSafeList"
  />
</template>
<script>
  import { Email } from 'vuntangle'
  import Util from '@/util/util'
  import Rpc from '@/util/Rpc'

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

      userSafeList() {
        return this.smtpSettings?.userSafeList || []
      },
      globalSafeList() {
        return this.smtpSettings?.globalSafeList || []
      },

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
      this.$store.dispatch('apps/loadAppData', 'smtp')
      this.$store.dispatch('config/getMailSender', true)
    },

    methods: {
      /**
       * Send test email
       * @param {object} email - The email address to send test mail to.
       * @param {function} cb - The callback function.
       */
      async sendTestEmail({ email, cb }) {
        try {
          const apiMethod = Rpc.asyncPromise('rpc.UvmContext.mailSender().sendTestMessageV2', email)
          const result = await apiMethod()
          if (result?.code && result?.message) {
            Util.handleException(result.message)
            cb(result.message)
          } else {
            cb(result)
          }
        } catch (err) {
          Util.handleException(err)
          cb(err)
        }
      },

      /**
       * Saves email server settings.
       * @param {object} emailServerSettings - The email server settings to save.
       * @param {function} cb - The callback function.
       */
      async onSaveEmailServerSettings({ updatedSettings, cb }) {
        this.$store.commit('SET_LOADER', true)
        try {
          // Save email server settings
          const response = await this.$store.dispatch('config/setMailSender', updatedSettings.emailServerSettings)
          // Save global safelist if provided
          if (updatedSettings.globalSafeList) {
            await this.$store.dispatch('apps/setGlobalSafeList', updatedSettings.globalSafeList)
          }
          // Reload SMTP app data
          await this.$store.dispatch('apps/loadAppData', 'smtp')
          // Call the callback with the original response
          cb(response)
        } catch (error) {
          // Optionally, handle error or pass it to the callback
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
      /**
       * Refreshes mail sender settings.
       */
      onRefreshSettings() {
        this.$store.commit('SET_LOADER', true)

        Promise.all([
          this.$store.dispatch('apps/loadAppData', 'smtp'),
          this.$store.dispatch('config/getMailSender', true),
        ]).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
      },
      async onPurgeUserSafeList(userEmails) {
        this.$store.commit('SET_LOADER', true)
        try {
          await this.$store.dispatch('apps/deleteSafelists', userEmails)
          await this.$store.dispatch('apps/loadAppData', 'smtp')
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
