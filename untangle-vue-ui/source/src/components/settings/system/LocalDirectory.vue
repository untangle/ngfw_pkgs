<template>
  <settings-local-directory
    :settings="processedUsers"
    :time-zone-offset="timeZoneOffset"
    :radius-logs-info="radiusLogsInfo"
    @get-secret-qr="getSecretQr"
    @get-secret-key="getSecretKey"
    @refresh-radius-logs-info="onRefreshRadiusLogFileInfo"
  >
    <template #actions="{ newSettings, isDirty, validate }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSave(newSettings, validate)"> {{ $t('save') }}</u-btn>
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
        const isValid = await validate()
        if (!isValid) return
        store.commit('SET_LOADER', true)
        const processedUsers = newSettings.map(u => {
          const user = { ...u }

          // Handle password
          if (!user.password) {
            user.password = ''
          }

          if (user.password.length > 0) {
            user.passwordBase64Hash = Util.base64encode(user.password)
            user.password = ''
          }

          // Handle expirationTime logic
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
          // this.$store.dispatch('config/setSystemSettings', systemSettings),
          this.$store.dispatch('config/setUsersSettings', processedUsers),
        ]).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
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
