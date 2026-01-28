<template>
  <email
    :smtp-settings="smtpSettings"
    :public-url="publicUrl"
    :mail-sender-settings="mailSender"
    :company-name="companyName"
    :global-safe-list="globalSafeList"
    :user-safe-list="userSafeList"
    @email-test="sendTestEmail"
    @save-settings="onSaveSettings"
    @refresh-settings="onRefreshSettings"
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
      publicUrl: ({ $store }) => $store.getters['config/publicUrl'],
      /**
       * Mail sender settings from Vuex store.
       * @returns {object}
       */
      mailSender: ({ $store }) => $store.getters['config/mailSender'],
      /**
       * SMTP settings from Vuex store.
       * @returns {object}
       */
      smtpAppSettings: ({ $store }) => $store.getters['apps/getSettings']('smtp'),

      smtpSettings() {
        return this.smtpAppSettings?.smtpSettings || {}
      },
      userSafeList() {
        return this.smtpAppSettings?.userSafeList || []
      },
      globalSafeList() {
        return this.smtpAppSettings?.globalSafeList || []
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
      this.$store.dispatch('config/getPublicUrl', true)
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
       * Saves email settings.
       * @param {object} updatedSettings - The email settings to save.
       * @param {function} cb - The callback function.
       */
      async onSaveSettings({ updatedSettings }) {
        this.$store.commit('SET_LOADER', true)
        try {
          // Save email server settings
          await this.$store.dispatch('config/setMailSender', updatedSettings.emailServerSettings)
          // Save global safelist if provided
          if (updatedSettings.globalSafeList) {
            await this.$store.dispatch('apps/setGlobalSafeList', updatedSettings.globalSafeList)
          }
          // Save smtpSettings settings if provided
          if (updatedSettings.smtpSettings) {
            await this.$store.dispatch('apps/setSmtpSettingsWOSafeList', updatedSettings.smtpSettings)
          }
          // Reload SMTP app data
          await this.$store.dispatch('apps/loadAppData', 'smtp')
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
          this.$store.dispatch('config/getPublicUrl', false),
        ]).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
      },
    },
  }
</script>
