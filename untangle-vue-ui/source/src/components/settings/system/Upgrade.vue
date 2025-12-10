<template>
  <v-container>
    <!-- Upgrades settings section -->
    <u-alert class="my-4">
      <template v-if="upgradeText">
        {{ $t('system_running_latest_version') }}
      </template>
      <template v-else-if="showUpgradeIssues">
        {{ $t('unable_to_upgrade') }}
        <div v-html="upgradeIssueText"></div>
      </template>
      <template v-else-if="showUpgradeButton">
        {{ $t('new_version_available') }}
        <u-btn :small="false" class="ml-4" @click="onUpgradeNowClick">{{ $t('upgrade_now') }}</u-btn>
      </template>
    </u-alert>
    <u-section>
      <appliance-upgrade :settings="settings">
        <template #boxActions="{ upgradeData }">
          <u-btn class="mt-4" @click="onSaveAutoUpgrade(upgradeData)">{{ $t('save') }}</u-btn>
        </template>
      </appliance-upgrade>
    </u-section>

    <!-- Disk Health Warning Dialog -->
    <v-dialog v-model="diskHealthDialog" max-width="500">
      <v-card>
        <v-card-title>{{ $t('warning') }}</v-card-title>
        <v-card-text>
          <div v-html="diskHealthMessage"></div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <u-btn @click="cancelDiskIssue">{{ $t('cancel') }}</u-btn>
          <u-btn color="primary" @click="proceedWithDiskIssue">{{ $t('ok') }}</u-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Download Progress Dialog -->
    <v-dialog v-model="downloadDialog" persistent max-width="420">
      <v-card class="pa-4 text-center">
        <v-progress-circular v-if="downloadProgress === 0" indeterminate size="32" class="mb-3" />
        <v-progress-linear v-else :value="downloadProgress * 100" height="8" class="mb-3" />
        <div>{{ downloadText }}</div>
      </v-card>
    </v-dialog>

    <v-dialog v-model="upgradeDialog" persistent max-width="600">
      <v-card class="pa-4 text-center">
        <v-progress-circular v-if="showSpinner" indeterminate size="24" class="mb-3" />
        <v-card-title>{{ upgradeDialogTitle }}</v-card-title>
      </v-card>
    </v-dialog>

    <v-dialog v-model="showDialog" persistent max-width="300">
      <v-card class="pa-4 text-center">
        <v-progress-circular v-if="showSpinner" indeterminate size="24" class="mb-3" />
        <v-card-title>{{ title }}</v-card-title>
        <v-card-text>{{ text }}</v-card-text>
        <u-btn @click="closeWarning">{{ $t('ok') }}</u-btn>
      </v-card>
    </v-dialog>
  </v-container>
</template>
<script>
  import { ApplianceUpgrade } from 'vuntangle'
  import store from '@/store'
  import Util from '@/util/setupUtil'

  export default {
    components: { ApplianceUpgrade },
    data: () => ({
      showUpgradeButton: false,
      isUpgradeAvailable: null,
      showUpgradeIssues: false,
      upgradeIssueText: '',
      upgradeText: false,
      diskHealthMessage: '',
      diskHealthDialog: false,
      downloadDialog: false,
      downloadText: '',
      checkDownloadStatus: false,
      downloadProgress: 0,
      upgradeDialog: false,
      upgradeDialogTitle: '',
      showSpinner: false,
      title: '',
      text: '',
      showDialog: false,
    }),

    computed: {
      settings: ({ $store }) => $store.getters['config/systemSetting'],
    },

    created() {
      this.$store.dispatch('config/getSystemSettings', false)
      this.checkUpgrades()
    },

    methods: {
      closeWarning() {
        this.showDialog = false
      },

      async checkUpgrades() {
        this.$store.commit('SET_LOADER', true)

        this.isUpgradeAvailable = await new Promise((resolve, reject) =>
          window.rpc.systemManager.upgradesAvailable((res, err) => (err ? reject(err) : resolve(res))),
        ).finally(() => this.$store.commit('SET_LOADER', false))

        if (this.isUpgradeAvailable) {
          this.canUpgrade()
        } else {
          this.upgradeText = true
        }
        this.$store.commit('SET_LOADER', false)
      },

      async canUpgrade() {
        try {
          this.$store.commit('SET_LOADER', true)
          const result = await new Promise((resolve, reject) =>
            window.rpc.systemManager.canUpgrade((res, err) => (err ? reject(err) : resolve(res))),
          ).finally(() => this.$store.commit('SET_LOADER', false))

          this.showUpgradeIssues = false
          this.showUpgradeButton = false
          const issues = result?.set || {}
          this.upgradeIssueText = issues
          const numIssues = Object.keys(issues).length
          if (numIssues === 0) {
            this.showUpgradeButton = true
            this.upgradeIssueText = ''
          } else {
            this.showUpgradeButton = false
            this.upgradeIssueText = this.formatIssueMessage(issues)
            this.showUpgradeIssues = true
          }
        } catch (ex) {
          Util.handleException(ex)
        }
      },

      formatIssueMessage(issues) {
        let msg = `upgrades_are_ready_but_unable_to_install<br/>`
        switch (issues) {
          case 'LOW_DISK':
            msg += `• ${this.$t('not_enough_disk_space')}`
            break
          default:
            msg += `${this.$t('unknown_issue')}: ${issues}`
            break
        }
        return msg
      },

      // saves the auto upgrade settings
      async onSaveAutoUpgrade(upgradeData) {
        if (upgradeData.enabled) {
          if (upgradeData.autoUpgradeDays === '') {
            this.title = this.$t('warning')
            this.text = this.$t('automatic_upgrade_message')
            this.showDialog = true
            return
          }
        }
        store.commit('SET_LOADER', true)
        const response = await store.dispatch('config/setSystemSettings', upgradeData)
        if (response.success) {
          this.$vuntangle.toast.add(this.$t('saved_successfully', [this.$t('settings')]))
        } else {
          this.$vuntangle.toast.add(this.$t('rolled_back_settings', [response.message]))
        }
        store.commit('SET_LOADER', false)
      },

      async onUpgradeNowClick() {
        this.$store.commit('SET_LOADER', true)
        const diskHealthStatus = await new Promise((resolve, reject) =>
          window.rpc.systemManager.checkDiskHealth((res, err) => (err ? reject(err) : resolve(res))),
        ).finally(() => this.$store.commit('SET_LOADER', false))
        if (diskHealthStatus.includes("'fail'")) {
          this.diskHealthMessage = this.$t('disk_health_message')
          this.diskHealthDialog = true
        } else {
          this.downloadUpgrades()
        }
      },

      proceedWithDiskIssue() {
        this.diskHealthDialog = false
        this.setSkipDiskCheckFlag(true)
        this.downloadUpgrades()
      },

      cancelDiskIssue() {
        this.diskHealthDialog = false
      },

      setSkipDiskCheckFlag(skipDiskCheck) {
        window.rpc.systemManager.setSkipDiskCheck(skipDiskCheck)
      },

      async downloadUpgrades() {
        this.downloadText = this.$t('downloading_upgrade')
        this.checkDownloadStatus = true

        this.$store.commit('SET_LOADER', true)
        const downloadUpgrades = await new Promise((resolve, reject) =>
          window.rpc.systemManager.downloadUpgrades((res, err) => (err ? reject(err) : resolve(res))),
        ).finally(() => this.$store.commit('SET_LOADER', false))
        this.checkDownloadStatus = false

        if (downloadUpgrades) {
          this.upgrade()
        } else {
          this.showDialog = true
          this.title = this.$t('warning')
          this.text = this.$t('downloading_failed')
          this.setSkipDiskCheckFlag(false)
        }
        this.getDownloadStatus()
      },

      async getDownloadStatus() {
        if (!this.checkDownloadStatus) return
        this.downloadDialog = true
        let downloadStatus = await window.rpc.systemManager.getDownloadStatus()
        if (!this.checkDownloadStatus) return

        downloadStatus =
          `${this.$t('package')}: ${downloadStatus.downloadCurrentFileCount} / ${
            downloadStatus.downloadTotalFileCount
          }<br>` + `${this.$t('speed')}: ${downloadStatus.downloadCurrentFileRate}`

        // Calculate progress
        let fileProgress = 0
        if (downloadStatus.downloadCurrentFileProgress) {
          fileProgress = parseFloat(downloadStatus.downloadCurrentFileProgress.replace('%', '')) / 100
        }

        let fileIndex = parseFloat(downloadStatus.downloadCurrentFileCount)
        if (fileIndex > 0) fileIndex -= 1

        const totalFiles = downloadStatus.downloadTotalFileCount || 1

        const percent = (fileIndex + fileProgress) / totalFiles

        // Match ExtJS logic (0.99 * percent)
        this.downloadProgress = 0.99 * percent

        if (percent < 1 && this.checkDownloadStatus) {
          setTimeout(() => this.getDownloadStatus(), 500)
        } else {
          // completed
          this.downloadDialog = false
        }
      },

      async upgrade() {
        Util.ignoreExceptions = true
        this.ignoreUpgradeExceptions = true

        this.upgradeDialog = true
        this.upgradeDialogTitle = this.$t('launching_message')
        this.showSpinner = true

        await new Promise((resolve, reject) => {
          window.rpc.systemManager.upgrade((res, err) => {
            if (err) {
              reject(err)
              return
            }
            this.startProcessingUpgradePhase()
            this.showSpinner = false
            resolve(res)
          })
        })
      },

      startProcessingUpgradePhase() {
        this.upgradeDialogTitle = this.$t('upgrade_message')
        this.upgradeDialog = false
        this.showUpgradeFinalMessage()
      },

      showUpgradeFinalMessage() {
        this.showSpinner = false
        this.showDialog = true
        this.title = this.$t('upgrade_in_progress')
        this.text = this.$t('upgrade_complete_message')
      },

      onClickOk() {
        window.location.reload()
        this.showDialog = false
      },

      /**
       * Optional hook triggered on browser refresh.
       * Fetches updated system settings and updates the store.
       */
      onBrowserRefresh() {
        this.$store.dispatch('config/getSystemSettings', true)
      },
    },
  }
</script>
