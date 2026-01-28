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
        {{ $vuntangle.$t('back_to_policy') }} [{{ selectedPolicy.name }}]
      </v-btn>
      <v-spacer></v-spacer>
      <v-btn v-if="policyManagerInstalled && !installMode" color="primary" @click="managePolicies">
        <v-icon small class="mr-2">mdi-cog</v-icon>
        {{ $vuntangle.$t('manage_policies') }}
      </v-btn>
      <v-btn v-if="!installMode" color="primary" class="ml-2" @click="installApps">
        <v-icon small class="mr-2">mdi-plus</v-icon>
        {{ $vuntangle.$t('install_apps') }}
      </v-btn>
    </div>
    <div class="d-flex flex-column fill-height">
      <h1 class="headline mb-2 mt-5">{{ $vuntangle.$t('apps') }}</h1>
      <div v-if="!installMode" class="d-flex flex-row flex-wrap" style="gap: 14px">
        <v-card
          v-for="(app, key) in filteredApps"
          :key="key"
          :elevation="hoveredApp === key ? 2 : 0"
          :outlined="hoveredApp === key"
          class="app-card"
          style="flex-basis: 13%"
          :disabled="!!app.policyName"
          @mouseover="hoveredApp = key"
          @mouseleave="hoveredApp = null"
        >
          <v-card-text class="text-center">
            <img :src="require(`@/assets/icons/apps/${app.appName}.svg`)" width="80" height="80" alt="App icon" />
          </v-card-text>
          <v-card-title
            data-testid="report-category-title"
            :class="`py-0 subtitle-1 d-flex justify-center ${$vuntangle.theme === 'dark' ? '' : 'primary--text'}`"
          >
            <div class="d-flex flex-column text-center">
              <span
                class="font-weight-medium"
                :style="{ cursor: app.policyName ? 'default' : 'pointer' }"
                @click="app.policyName ? null : goToApp(app)"
                >{{ $vuntangle.$t(app.appName) }} </span
              ><span v-if="app.policyName" class="caption">[{{ app.policyName }}]</span>
            </div>
          </v-card-title>
        </v-card>
      </div>
      <div v-else class="d-flex flex-row flex-wrap" style="gap: 14px">
        <v-card
          v-for="(app, key) in installableApps"
          :key="key"
          :elevation="hoveredApp === key ? 2 : 0"
          :outlined="hoveredApp === key"
          class="app-card"
          style="flex-basis: 24%"
          @mouseover="hoveredApp = key"
          @mouseleave="hoveredApp = null"
        >
          <div class="d-flex align-center">
            <div style="width: 120px">
              <v-card-text class="text-center pa-2">
                <img :src="require(`@/assets/icons/apps/${app.name}.svg`)" width="80" height="80" alt="App icon" />
              </v-card-text>
            </div>
            <div>
              <v-card-title
                data-testid="report-category-title"
                :class="`py-0 subtitle-1 d-flex justify-center ${$vuntangle.theme === 'dark' ? '' : 'primary--text'}`"
              >
                <div class="d-flex flex-column">
                  <span class="font-weight-medium text-left">{{ $vuntangle.$t(app.displayName) }} </span>
                  <span class="caption text-left">{{ appDescription[app.name] }}</span>
                </div>
              </v-card-title>
            </div>
          </div>
        </v-card>
      </div>
    </div>
  </v-container>
</template>

<script>
  import util from '@/util/util'
  import { appDescription } from '@/constants/index'

  export default {
    name: 'AppsView',
    data() {
      return {
        hoveredApp: null,
        installMode: false,
        appDescription,
      }
    },
    computed: {
      policyManagerInstalled: () => util.isPolicyManagerInstalled(),
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
      filteredApps() {
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

        const apps = appNames.map(appName => {
          for (const policyId of policyHierarchy) {
            const view = this.appViews.find(v => v.policyId === policyId)
            const app = (view ? view.instances : []).find(a => a.appName === appName)
            if (app) {
              const _app = { ...app }
              if (app.policyId && app.policyId !== this.selectedPolicy.policyId) {
                _app.policyName = policyMap[app.policyId].name
              }
              return _app
            }
          }
          return null
        })

        return apps.filter(Boolean)
      },
      installableApps() {
        if (!this.appViews || !this.selectedPolicy) return []
        const policyView = this.appViews.find(v => v.policyId === this.selectedPolicy.policyId)
        if (!policyView) return []

        const installedApps = policyView.instances.map(app => app.appName)
        const installable = policyView.installable.filter(appName => !installedApps.includes(appName))

        return policyView.appProperties
          .filter(app => installable.includes(app.name) && app.type === 'FILTER')
          .map(app => ({ name: app.name, displayName: app.displayName }))
      },
    },
    created() {
      this.$store.dispatch('apps/loadAppData', 'policy-manager')
      this.$store.dispatch('apps/getAppViews', false)
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
      goToApp(app) {
        this.$router.push(`/apps/${this.selectedPolicy.policyId}/${app.appName}`)
      },

      installApps() {
        this.installMode = true
      },

      backToPolicy() {
        this.installMode = false
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
