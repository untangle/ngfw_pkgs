<template>
  <settings-local-directory
    :settings="commonSettings"
    :time-zone-offset="timeZoneOffset"
    :radius-logs-info="radiusLogsInfo"
    @get-secret-qr="getSecretQr"
    @get-secret-key="getSecretKey"
    @refresh-radius-logs-info="onRefreshRadiusLogFileInfo"
    @test-radius-proxy-login="getTestRadiusProxy"
    @refresh-ad-account-status="getAdAccountStatus"
    @create-ad-account-status="createComputerAccount"
  >
    <template #actions="{ newSettings, isDirty, validate }">
      <u-btn :disabled="!isDirty" @click="onSave(newSettings, validate)"> {{ $t('save') }}</u-btn>
    </template>
  </settings-local-directory>
</template>
<script>
  import { SettingsLocalDirectory } from 'vuntangle'
  import store from '@/store'
  import Util from '@/util/setupUtil'
  import Rpc from '@/util/Rpc'

  export default {
    components: { SettingsLocalDirectory },
    data: () => ({
      showUpgradeButton: false,
      processedUsers: [],
    }),

    computed: {
      systemSettings: ({ $store }) => $store.getters['config/systemSetting'],
      users: ({ $store }) => $store.getters['config/users'],
      timeZoneOffset: ({ $store }) => $store.getters['config/timeZoneOffset'],
      radiusLogsInfo: ({ $store }) => $store.getters['config/radiusLogsInfo'],

      /**
       * Combines various settings into a single object for the Local Directory component.
       * @returns {Object} Combined settings object.
       */
      commonSettings() {
        return {
          systemSettings: this.systemSettings,
          usersSettings: this.processedUsers,
        }
      },
    },

    created() {
      this.$store.dispatch('config/getSystemSettings', false)
      this.$store.dispatch('config/getUsers', false)
      this.$store.dispatch('config/getTimeZoneOffSet')
      this.$store.dispatch('config/getRadiusLogFile')
      this.getOriginalpassword()
      this.processUsers()
    },

    methods: {
      processUsers() {
        this.processedUsers = this.users.map(user => {
          const isForever = user.expirationTime === 0
          return {
            ...user,
            localEmpty: false,
            localForever: isForever,
            localExpires: isForever ? new Date() : new Date(user.expirationTime),
          }
        })
      },

      getOriginalpassword() {
        const encryptedPassword = this.systemSettings.radiusProxyEncryptedPassword
        if (encryptedPassword !== null && encryptedPassword !== '') {
          const password = Util.getDecryptedPassword(encryptedPassword)
          this.systemSettings.radiusProxyPassword = password
        }
      },

      async getSecretKey(cb) {
        this.$store.commit('SET_LOADER', true)
        const response = await Rpc.asyncData('rpc.UvmContext.localDirectory.generateSecret').finally(() =>
          this.$store.commit('SET_LOADER', false),
        )
        cb(response ?? null)
      },

      async onRefreshRadiusLogFileInfo() {
        await this.$store.dispatch('config/getRadiusLogFile')
      },
      async getTestRadiusProxy(testuser, testpass, testdom, cb) {
        this.$store.commit('SET_LOADER', true)
        const response = await Rpc.asyncData(
          'rpc.UvmContext.localDirectory().testRadiusProxyLogin',
          testuser,
          testpass,
          testdom,
        ).finally(() => this.$store.commit('SET_LOADER', false))
        cb(response ?? null)
      },

      async getAdAccountStatus(cb) {
        if (this.systemSettings.radiusProxyEnabled === false) {
          cb(null)
          return
        }
        this.$store.commit('SET_LOADER', true)
        const response = await Rpc.asyncData('rpc.UvmContext.localDirectory().getRadiusProxyStatus').finally(() =>
          this.$store.commit('SET_LOADER', false),
        )
        cb(response ?? null)
      },

      async createComputerAccount(cb) {
        if (this.systemSettings.radiusProxyEnabled === false) {
          cb(null)
          return
        }
        this.$store.commit('SET_LOADER', true)
        const response = await Rpc.asyncData('rpc.UvmContext.localDirectory().addRadiusComputerAccount').finally(() =>
          this.$store.commit('SET_LOADER', false),
        )
        cb(response.output ?? null)
      },

      async getSecretQr(username, twofactorSecretKey, cb) {
        const response = await Rpc.asyncData(
          'rpc.UvmContext.localDirectory.showSecretQR',
          username,
          'Untangle',
          twofactorSecretKey,
        )
        cb(response ?? null)
      },

      // saves the auto upgrade settings
      async onSave(newSettings, validate) {
        let dirtyRadiusFields = false
        const isValid = await validate()
        if (!isValid && validate) return
        store.commit('SET_LOADER', true)

        const { systemSettings: newSystemSettings, usersSettings: newUsersSettings } = newSettings

        if (!this.isEqual(newSystemSettings, this.systemSettings)) {
          dirtyRadiusFields = true
        }
        const processedUsers = newUsersSettings.map(u => {
          const user = { ...u }

          // Handle password
          if (!user.password) {
            user.password = ''
          }
          // calculate the passwordBase64Hash for any changed passwords and remove cleartext
          if (user.password.length > 0) {
            user.passwordBase64Hash = Util.base64encode(user.password)
            user.password = ''
          }

          // use localForever and localExpires to set the correct expirationTime
          if (user.localForever === true) {
            user.expirationTime = 0
          } else {
            if (!(user.localExpires instanceof Date)) {
              user.localExpires = new Date(user.localExpires)
            }
            user.expirationTime = user.localExpires.getTime()
          }

          return user
        })

        // Make sure we set the userlist last because that function will generate
        // the user credentials and shared secret configs for the freeradius server
        await Promise.all([
          this.$store.dispatch('config/setSystemSettings', { systemSettings: newSystemSettings, dirtyRadiusFields }),
          this.$store.dispatch('config/setUsersSettings', processedUsers),
        ]).finally(() => {
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
       * Fetches updated system settings and updates the store.
       */
      onBrowserRefresh() {
        this.$store.dispatch('config/getSystemSettings', true)
        this.$store.dispatch('config/getUsers', true)
      },
    },
  }
</script>
