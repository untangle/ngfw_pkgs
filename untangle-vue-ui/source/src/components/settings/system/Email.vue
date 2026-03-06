<template>
  <email
    :smtp-settings="smtpSettings"
    :smtp-enabled="smtpEnabled"
    :public-url="publicUrl"
    :mail-sender-settings="mailSender"
    :company-name="companyName"
    :global-safe-list="globalSafeList"
    :user-safe-list="userSafeList"
    :inboxes-list="inboxesList"
    :total-disk-space="totalDiskSpace"
    @email-test="sendTestEmail"
    @save-settings="onSaveSettings"
    @refresh-settings="onRefreshSettings"
    @refresh-user-quarantines="onRefreshUserQuarantines"
    @purge-user-safe-list="onPurgeUserSafeList"
    @purge-quarantined-user-email="purgeQuarantinedUserEmail"
    @release-quarantined-user-email="releaseQuarantinedUserEmail"
    @quarantine-inbox-records-by-account="getQuarantineInboxRecordsByAccount"
    @purge-user-qurantine-list="onPurgeUserQuarantineList"
    @release-user-qurantine-list="onReleaseUserQuarantineList"
  />
</template>
<script>
  import { Email } from 'vuntangle'
  import Rpc from '@/util/Rpc'

  /**
   * Wrapper component for email system settings and quarantine management.
   * Handles SMTP configuration, email server settings, safelists, and user quarantine operations.
   * Integrates with Vuex store for state management and the SMTP app for quarantine operations.
   */
  export default {
    components: { Email },
    data() {
      return {
        /**
         * Whether SMTP app is enabled/available.
         * @type {boolean}
         */
        smtpEnabled: false,
      }
    },
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
        return this.smtpAppSettings?.settings || null
      },
      userSafeList() {
        return this.smtpAppSettings?.userSafeList || []
      },
      globalSafeList() {
        return this.smtpAppSettings?.globalSafeList || []
      },
      inboxesList() {
        return this.smtpAppSettings?.inboxSummary?.inboxesList
      },
      totalDiskSpace() {
        return this.smtpAppSettings?.inboxSummary?.totalDiskSpace
      },
      companyName() {
        // TODO cache company name (can only be done once we migrate Branding Manager to Vue)
        return window?.rpc?.companyName || null
      },
    },
    /**
     * Initializes component by loading SMTP app availability status and fetching
     * initial email configuration data including SMTP settings, mail sender config, and public URL.
     */
    async created() {
      const app = await this.$store.dispatch('apps/getApp', 'smtp')
      this.smtpEnabled = !!app
      this.$store.dispatch('apps/loadAppData', 'smtp')
      this.$store.dispatch('config/getMailSender', true)
      this.$store.dispatch('config/getPublicUrl', true)
    },

    methods: {
      /**
       * Helper method to get the SMTP app instance
       * @returns {Promise<Object|null>} The SMTP app instance or null
       */
      async getSmtpApp() {
        return await this.$store.dispatch('apps/getApp', 'smtp')
      },

      /**
       * Wraps a callback-based API call into a Promise
       * @param {Function} apiCall - The API call function that accepts a callback
       * @returns {Promise} Promise that resolves with the result or rejects with an error
       */
      promisifyAppCall(apiCall) {
        return new Promise((resolve, reject) => {
          apiCall((ex, res) => {
            if (ex || res?.code) {
              reject(ex || res?.message || 'Unknown error')
            } else {
              resolve(res)
            }
          })
        })
      },

      /**
       * Retrieves quarantined email records for a specific user account.
       * @param {Object} params - Parameters object
       * @param {string} params.account - The user account email address
       * @param {function} params.cb - Callback function invoked with results or error
       */
      async getQuarantineInboxRecordsByAccount({ account, cb }) {
        try {
          const app = await this.getSmtpApp()
          if (!app) {
            cb(new Error('SMTP app not available'))
            return
          }

          app.getQuarantineMaintenenceView().getInboxRecordsV2((res, ex) => {
            if (ex || res?.code) {
              cb(ex || res?.message)
            } else {
              cb(res)
            }
          }, account)
        } catch (error) {
          cb(error)
        }
      },

      /**
       * Permanently deletes selected quarantined emails for a specific user account.
       * @param {Object} params - Parameters object
       * @param {string} params.account - The user account email address
       * @param {Array<string>} params.emails - Array of email IDs to permanently delete
       * @param {function} params.cb - Callback function invoked with results or error
       */
      async purgeQuarantinedUserEmail({ account, emails, cb }) {
        try {
          const app = await this.getSmtpApp()
          if (!app) {
            cb(new Error('SMTP app not available'))
            return
          }

          app.getQuarantineMaintenenceView().purge(
            (ex, res) => {
              if (ex || res?.code) {
                cb(ex || res?.message)
              } else {
                cb(res)
              }
            },
            account,
            emails,
          )
        } catch (error) {
          cb(error)
        }
      },

      /**
       * Releases and delivers selected quarantined emails to the user's inbox.
       * @param {Object} params - Parameters object
       * @param {string} params.account - The user account email address
       * @param {Array<string>} params.emails - Array of email IDs to release from quarantine
       * @param {function} params.cb - Callback function invoked with results or error
       */
      async releaseQuarantinedUserEmail({ account, emails, cb }) {
        try {
          const app = await this.getSmtpApp()
          if (!app) {
            cb(new Error('SMTP app not available'))
            return
          }

          app.getQuarantineMaintenenceView().rescue(
            (ex, res) => {
              if (ex || res?.code) {
                cb(ex || res?.message)
              } else {
                cb(res)
              }
            },
            account,
            emails,
          )
        } catch (error) {
          cb(error)
        }
      },

      /**
       * Sends a test email to verify mail server configuration.
       * @param {Object} params - Parameters object
       * @param {string} params.email - The destination email address for the test message
       * @param {function} params.cb - Callback function invoked with results or error
       */
      async sendTestEmail({ email, cb }) {
        try {
          const apiMethod = Rpc.asyncPromise('rpc.UvmContext.mailSender().sendTestMessageV2', email)
          const result = await apiMethod()
          if (result?.code && result?.message) {
            cb(result.message)
          } else {
            cb(result)
          }
        } catch (error) {
          cb(error)
        }
      },

      /**
       * Saves updated email configuration including server settings, SMTP settings, and global safelist.
       * @param {Object} params - Parameters object
       * @param {Object} params.updatedSettings - The updated email settings
       * @param {Object} params.updatedSettings.emailServerSettings - Mail server configuration
       * @param {Array} [params.updatedSettings.globalSafeList] - Global email safelist (optional)
       * @param {Object} [params.updatedSettings.smtpSettings] - SMTP-specific settings (optional)
       */
      async onSaveSettings({ updatedSettings }) {
        this.$store.commit('SET_LOADER', true)
        try {
          const app = await this.getSmtpApp()
          if (!app) {
            return
          }

          await this.$store.dispatch('config/setMailSender', updatedSettings.emailServerSettings)
          // Save global safelist if provided
          if (updatedSettings.globalSafeList) {
            await app.getSafelistAdminView().replaceSafelist('GLOBAL', updatedSettings.globalSafeList)
          }
          // Save smtpSettings settings if provided
          if (updatedSettings.smtpSettings) {
            await this.promisifyAppCall(cb => app.setSmtpSettingsWithoutSafelistsV2(cb, updatedSettings.smtpSettings))
          }
          // Reload SMTP app data
          await this.$store.dispatch('apps/loadAppData', 'smtp')
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
      /**
       * Reloads all email-related settings from the server including SMTP app data,
       * mail sender configuration, and public URL.
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
      /**
       * Refreshes the quarantine inbox summary data for all users,
       * including inbox counts and total disk space usage.
       */
      async onRefreshUserQuarantines() {
        this.$store.commit('SET_LOADER', true)
        try {
          await this.$store.dispatch('apps/makeRegistryCall', {
            appName: 'smtp',
            apiKey: 'inboxSummary',
          })
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Deletes the safelist (allowed sender list) for specified user accounts.
       * @param {Array<string>} userEmails - Array of user email addresses whose safelists should be deleted
       */
      async onPurgeUserSafeList(userEmails) {
        this.$store.commit('SET_LOADER', true)
        try {
          const app = await this.getSmtpApp()
          if (!app) {
            return
          }

          await this.promisifyAppCall(cb => app.getSafelistAdminView().deleteSafelists(cb, userEmails))

          await this.$store.dispatch('apps/loadAppData', 'smtp')
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Permanently deletes all quarantined emails for specified user accounts.
       * This removes entire quarantine inboxes and all contained emails.
       * @param {Array<string>} userEmails - Array of user email addresses whose quarantine inboxes should be deleted
       */
      async onPurgeUserQuarantineList(userEmails) {
        this.$store.commit('SET_LOADER', true)
        try {
          const app = await this.getSmtpApp()
          if (!app) {
            return
          }

          await this.promisifyAppCall(cb => app.getQuarantineMaintenenceView().deleteInboxes(cb, userEmails))

          await this.onRefreshUserQuarantines()
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Releases and delivers all quarantined emails for specified user accounts to their inboxes.
       * This processes entire quarantine inboxes and releases all contained emails.
       * @param {Array<string>} userEmails - Array of user email addresses whose quarantined emails should be released
       */
      async onReleaseUserQuarantineList(userEmails) {
        this.$store.commit('SET_LOADER', true)
        try {
          const app = await this.getSmtpApp()
          if (!app) {
            return
          }

          await this.promisifyAppCall(cb => app.getQuarantineMaintenenceView().rescueInboxes(cb, userEmails))

          await this.onRefreshUserQuarantines()
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
