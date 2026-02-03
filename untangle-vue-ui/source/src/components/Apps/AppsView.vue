<template>
  <v-container fluid :class="`d-flex flex-column flex-grow-1 pl-3 pt-2`">
    <div class="d-flex align-center mb-2">
      <v-menu v-if="policyManagerInstalled && !installMode" offset-y content-class="policy-menu">
        <template #activator="{ on }">
          <v-btn color="primary" v-on="on"
            ><v-icon small class="mr-2">mdi-file-document-outline</v-icon>{{ selectedPolicy.name }}
            <v-icon small class="ml-2">mdi-chevron-down</v-icon></v-btn
          >
        </template>
        <v-treeview
          :items="hierarchicalPolicies"
          item-key="policyId"
          item-text="name"
          activatable
          hoverable
          dense
          open-all
          @update:active="onPolicyChange"
        ></v-treeview>
      </v-menu>
      <v-btn v-if="installMode" color="primary" @click="backToPolicy">
        <v-icon small class="mr-2">mdi-arrow-left</v-icon>
        {{ $vuntangle.$t('back_to_apps') }} [{{ selectedPolicy.name }}]
      </v-btn>
      <p v-if="autoInstallApps" class="body-3 mb-0 ml-3">
        {{ $vuntangle.$t('installing_recommended_apps') }}
      </p>
      <p v-if="policyManagerInstalled && installMode" class="body-3 mb-0 ml-3">
        {{ $vuntangle.$t('available_apps_for') }}
        <span
          ><v-icon small class="mb-1 mr-1">mdi-file-document-outline</v-icon
          ><strong>{{ selectedPolicy.name }}</strong></span
        >
      </p>
      <v-spacer></v-spacer>
      <v-btn v-if="policyManagerInstalled && !installMode" color="primary" @click="managePolicies">
        <v-icon small class="mr-2">mdi-cog</v-icon>
        {{ $vuntangle.$t('manage_policies') }}
      </v-btn>
      <v-btn
        v-if="!installMode && !isRestricted && isRegistered && licenseServerConnectivity"
        color="primary"
        class="ml-2"
        @click="installApps"
      >
        <v-icon small class="mr-2">mdi-plus</v-icon>
        {{ $vuntangle.$t('install_apps') }}
      </v-btn>
    </div>
    <div class="d-flex flex-column fill-height">
      <h1 class="headline mb-2 mt-5">{{ $vuntangle.$t('apps') }}</h1>
      <v-divider class="my-2 pt-2" />
      <installed-apps v-if="!installMode" :installed-apps="installedApps" />
      <installable-apps v-else :apps="installableApps" />
    </div>
  </v-container>
</template>

<script>
  import InstalledApps from './InstalledApps.vue'
  import InstallableApps from './InstallableApps.vue'
  import util from '@/util/util'
  import { appDescription } from '@/constants/index'

  export default {
    name: 'AppsView',
    components: {
      InstalledApps,
      InstallableApps,
    },
    data() {
      return {
        installMode: false,
        autoInstallApps: false,
        timeout: null,
      }
    },
    computed: {
      policyManagerInstalled: () => util.isPolicyManagerInstalled(),
      isRestricted: () => util.isRestricted(),
      isRegistered: () => util.isRegistered(),
      licenseServerConnectivity: () => util.getLicenseServerConnectivity(),
      policyManagerSettings: ({ $store }) => $store.getters['apps/getSettings']('policy-manager'),
      policies: ({ policyManagerSettings }) => (policyManagerSettings ? policyManagerSettings.policies || [] : []),
      appViews: ({ $store }) => $store.getters['apps/appViews'],
      policyId: ({ $route }) => $route.params.policyId || 1,
      selectedPolicy({ policies, policyId }) {
        return policies.find(p => p.policyId.toString() === policyId.toString()) || policies[0]
      },
      hierarchicalPolicies() {
        const policyMap = {}
        this.policies.forEach(policy => {
          policyMap[policy.policyId] = { ...policy, children: [] }
        })

        const tree = []
        this.policies.forEach(policy => {
          if (!policy.parentId) {
            tree.push(policyMap[policy.policyId])
          } else if (policyMap[policy.parentId]) {
            policyMap[policy.parentId].children.push(policyMap[policy.policyId])
          }
        })

        return tree
      },
      installedApps() {
        if (!this.appViews || !this.selectedPolicy) return []
        const policyMap = this.policies.reduce((acc, policy) => {
          acc[policy.policyId] = policy
          return acc
        }, {})

        let currentPolicy = this.selectedPolicy
        const policyHierarchy = [currentPolicy.policyId]

        while (currentPolicy && currentPolicy.parentId) {
          currentPolicy = policyMap[currentPolicy.parentId]
          if (currentPolicy) {
            policyHierarchy.push(currentPolicy.policyId)
          }
        }

        const allApps = policyHierarchy.reduce((acc, policyId) => {
          const view = this.appViews.find(v => v.policyId === policyId)
          return acc.concat(view ? view.instances : [])
        }, [])

        const appNames = [...new Set(allApps.filter(app => app.policyId !== null).map(app => app.appName))]

        let apps = appNames.map(appName => {
          for (const policyId of policyHierarchy) {
            const view = this.appViews.find(v => v.policyId === policyId)
            const app = (view ? view.instances : []).find(a => a.appName === appName)
            if (app) {
              const _app = { ...app }
              if (app.policyId && app.policyId !== this.selectedPolicy.policyId) {
                _app.parentPolicy = policyMap[app.policyId].name
              }
              const appProperties = view.appProperties.find(prop => prop.name === appName)
              const license = view.licenseMap[appName]
              _app.hasPowerButton = appProperties ? appProperties.hasPowerButton : false
              _app.displayName = appProperties ? appProperties.displayName : appName
              _app.licenseMessage = util.getLicenseMessage(license, this.$vuntangle)
              _app.powerCls = this.getPowerClass(_app, view.runStates[_app.id], appProperties.daemon)
              _app.installing = false
              _app.props = appProperties || {}
              return _app
            }
          }
          return null
        })

        apps = apps.sort(function (a, b) {
          if (a.props.viewPosition < b.props.viewPosition) {
            return -1
          }
          return 1
        })

        return apps.filter(Boolean)
      },
      installableApps() {
        if (!this.appViews || !this.selectedPolicy) return []
        const policyView = this.appViews.find(v => v.policyId === this.selectedPolicy.policyId)
        if (!policyView) return []

        let installableApps = []
        policyView.installable.forEach(appName => {
          const app = policyView.appProperties.find(a => a.name === appName)
          if (app && app.type === 'FILTER') {
            installableApps.push({
              name: app.name,
              displayName: app.displayName,
              description: appDescription[app.name],
              route: '#apps/' + policyView.policyId + '/' + app.name,
              viewPosition: app.viewPosition,
            })
          }
        })

        installableApps = installableApps.sort(function (a, b) {
          if (a.viewPosition < b.viewPosition) {
            return -1
          }
          return 1
        })
        return installableApps
      },
    },
    created() {
      this.$store.dispatch('apps/loadAppData', 'policy-manager')
      // Need to fetch all app views only once
      this.$store.dispatch('apps/getAppViews', false)
      // For each policy, fetch its app view and update the store
      this.$store.dispatch('apps/getAppView', this.policyId)
    },
    mounted() {
      this.poll()
    },
    beforeDestroy() {
      clearTimeout(this.timeout)
    },
    methods: {
      onPolicyChange(active) {
        if (active.length > 0) {
          const changedPolicy = this.policies.find(p => p.policyId === active[0])
          this.$router.push(`/apps/${changedPolicy.policyId}`)
        }
      },
      managePolicies() {
        this.$router.push('/settings/services/dynamic-blocklist')
      },
      installApps() {
        this.installMode = true
      },

      backToPolicy() {
        this.installMode = false
      },
      poll() {
        const flag = window.rpc.appManager.isAutoInstallAppsFlag()

        this.autoInstallApps = flag
        if (!flag || this._isDestroyed) return

        clearTimeout(this.timeout)
        this.timeout = setTimeout(() => {
          this.poll()
        }, 250)
      },
      getPowerClass(app, runState, daemon) {
        const on = runState === 'RUNNING'
        const targetState = app.targetState
        const daemonRunning =
          on && daemon != null ? window.rpc.directData('rpc.UvmContext.daemonManager.isRunning', daemon) : true
        const inconsistent = targetState !== runState || (runState === 'RUNNING' && !daemonRunning)

        if (inconsistent) {
          return 'inconsistent'
        } else if (on) {
          return 'on'
        } else {
          return ''
        }
      },
    },
  }
</script>

<style scoped>
  .policy-menu {
    background-color: white;
    z-index: 1;
  }
</style>
