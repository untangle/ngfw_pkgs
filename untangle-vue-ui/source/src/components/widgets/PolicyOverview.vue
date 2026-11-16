<template>
  <u-widget :title="$t('policy_overview')" enable-expand :fetching="fetching" enable-refresh @refresh="loadData">
    <div style="height: 100%; overflow-y: auto">
      <v-simple-table dense>
        <template #default>
          <thead>
            <tr>
              <th class="text-left font-weight-bold black--text" style="font-size: 0.85rem">
                {{ $t('policy_name_id') }}
              </th>
              <th class="text-center font-weight-bold black--text" style="min-width: 110px; font-size: 0.85rem">
                {{ $t('apps_installed_running_inherited') }}
              </th>
              <th class="text-center font-weight-bold black--text" style="min-width: 70px; font-size: 0.85rem">
                {{ $t('sessions') }}
              </th>
              <th class="text-center font-weight-bold black--text" style="min-width: 70px; font-size: 0.85rem">
                {{ $t('traffic') }}
              </th>
              <th style="width: 36px"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="displayRows.length === 0">
              <td colspan="5" class="text-center grey--text py-4">{{ $t('no_policies_found') }}</td>
            </tr>

            <tr v-for="row in displayRows" :key="row.key" :class="{ 'app-row': row.type === 'app' }">
              <!-- Policy row -->
              <template v-if="row.type === 'policy'">
                <td>
                  <span :style="{ paddingLeft: row.level * 16 + 'px' }" class="d-flex align-center">
                    <v-icon v-if="row.level > 0" x-small class="mr-1 black--text">mdi-subdirectory-arrow-right</v-icon>
                    <span>{{ row.name }}</span>
                    <span class="grey--text text--lighten-1 ml-1">({{ row.policyId }})</span>
                  </span>
                </td>
                <td class="text-center">
                  <div class="d-flex align-center justify-center" style="gap: 10px">
                    <strong style="font-size: 1.1em">{{ row.installed }}</strong>
                    <span style="color: #4caf50">{{ row.running }}</span>
                    <span>{{ row.inherited }}</span>
                    <v-btn v-if="row.apps.length > 0" icon x-small @click="toggleExpand(row.policyId)">
                      <v-icon x-small>{{ expanded[row.policyId] ? 'mdi-chevron-up' : 'mdi-chevron-down' }}</v-icon>
                    </v-btn>
                  </div>
                </td>
                <td class="text-center">
                  <span v-if="row.sessionCount > 0">{{ row.sessionCount }}</span>
                  <span v-else class="grey--text text--lighten-1">0</span>
                </td>
                <td class="text-center">
                  <span v-if="row.totalBps > 0">{{ formatBytes(row.totalBps) }}/s</span>
                  <span v-else class="grey--text text--lighten-1">0</span>
                </td>
                <td class="text-center">
                  <v-btn icon x-small @click="navigate(row.policyId)">
                    <v-icon small>mdi-open-in-new</v-icon>
                  </v-btn>
                </td>
              </template>

              <!-- App row -->
              <template v-else-if="row.type === 'app'">
                <td colspan="4">
                  <div class="d-flex align-center" :style="{ paddingLeft: row.level * 16 + 48 + 'px', gap: '8px' }">
                    <span class="status-dot" :style="{ backgroundColor: row.running ? '#4caf50' : '#bdbdbd' }" />
                    <img
                      :src="getAppIcon(row.appName)"
                      :alt="row.displayName"
                      width="18"
                      height="18"
                      style="object-fit: contain"
                    />
                    <span class="body-2">{{ row.displayName }}</span>
                    <span v-if="row.inherited" class="grey--text caption ml-1">
                      <v-icon x-small class="grey--text">mdi-arrow-up</v-icon>
                      {{ row.parentPolicyName }}
                    </span>
                  </div>
                </td>
                <td class="text-center">
                  <v-btn icon x-small @click="navigate(row.policyId, row.appName)">
                    <v-icon small>mdi-open-in-new</v-icon>
                  </v-btn>
                </td>
              </template>
            </tr>
          </tbody>
        </template>
      </v-simple-table>
    </div>
  </u-widget>
</template>

<script>
  import widgetsMixin from './widgetsMixin'
  import { rpcCall } from '@/util/rpcHelpers'
  import util from '@/util/util'

  export default {
    mixins: [widgetsMixin],

    data: () => ({
      fetching: false,
      policiesStats: {},
      expanded: {},
    }),

    computed: {
      policies() {
        return this.$store.getters['apps/getSettings']('policy-manager')?.settings?.policies || []
      },

      appsViewByPolicy() {
        return this.$store.getters['apps/appsViewByPolicy'] || {}
      },

      flatPolicies() {
        if (!this.policies.length) return []
        const tree = this.buildTree(this.policies)
        const rows = []
        this.flattenTree(tree, rows, 0)
        return rows
      },

      // This computed property returns the rows to be displayed in the table, including both policy and app rows, based on the expanded state of each policy.
      displayRows() {
        const rows = []
        this.flatPolicies.forEach(policy => {
          rows.push({ ...policy, type: 'policy', key: 'policy-' + policy.policyId })
          if (this.expanded[policy.policyId]) {
            policy.apps.forEach(app => {
              rows.push({
                ...app,
                type: 'app',
                policyId: policy.policyId,
                level: policy.level,
                key: 'app-' + policy.policyId + '-' + app.appName,
              })
            })
          }
        })
        return rows
      },
    },

    methods: {
      // This method loads the necessary data for the component, including fetching the policies and their associated statistics.
      async loadData() {
        this.fetching = true
        await this.$store.dispatch('apps/getAppsViews', true)
        this.policiesStats =
          (await rpcCall(window.rpc?.sessionMonitor?.getPoliciesSessionsStats, [], { fallback: {} })) || {}
        this.fetching = false
      },

      // This method builds a tree structure from the flat list of policies, organizing them based on their parent-child relationships.
      buildTree(policies) {
        const map = {}
        policies.forEach(p => {
          map[p.policyId] = { ...p, children: [] }
        })
        const roots = []
        policies.forEach(p => {
          if (!p.parentId) {
            roots.push(map[p.policyId])
          } else if (map[p.parentId]) {
            map[p.parentId].children.push(map[p.policyId])
          }
        })
        return roots
      },

      // This method recursively flattens the tree structure of policies into a list of rows, including both policy and app information, while keeping track of the hierarchy level for indentation purposes.
      flattenTree(nodes, result, level) {
        const policyNameMap = {}
        this.policies.forEach(p => {
          policyNameMap[p.policyId] = p.name || `Policy ${p.policyId}`
        })

        nodes.forEach(node => {
          const view = this.appsViewByPolicy[node.policyId]
          const stats = this.policiesStats[String(node.policyId)] || {}

          let installed = 0
          let running = 0
          let inherited = 0
          const apps = []

          if (view && view.appProperties && view.instances) {
            const instancesByAppName = {}
            view.instances.forEach(inst => {
              if (inst.policyId !== null) instancesByAppName[inst.appName] = inst
            })

            view.appProperties.forEach(appProp => {
              if (appProp.type !== 'FILTER') return

              const inst = instancesByAppName[appProp.name]
              if (!inst) return

              const isInherited = String(inst.policyId) !== String(node.policyId)
              const isRunning = !!(view.runStates && view.runStates[inst.id] === 'RUNNING')

              installed++
              if (isRunning) running++
              if (isInherited) inherited++

              apps.push({
                appName: appProp.name,
                displayName: appProp.displayName || appProp.name,
                running: isRunning,
                inherited: isInherited,
                parentPolicyName: isInherited ? policyNameMap[inst.policyId] || '' : '',
              })
            })
          }

          result.push({
            policyId: node.policyId,
            name: node.name || `Policy ${node.policyId}`,
            level,
            installed,
            running,
            inherited,
            sessionCount: stats.sessionCount || 0,
            totalBps: stats.totalBps || 0,
            apps,
          })

          if (node.children.length) {
            this.flattenTree(node.children, result, level + 1)
          }
        })
      },

      toggleExpand(policyId) {
        this.$set(this.expanded, policyId, !this.expanded[policyId])
      },

      getAppIcon(appName) {
        try {
          return require(`@/assets/icons/apps/${appName}.svg`)
        } catch {
          return ''
        }
      },

      formatBytes(value) {
        return util.formatBytes(value)
      },

      // This method navigates to the policy or app details page based on the provided policyId and optional appName.
      // It constructs the URL and updates the parent window's location to navigate to the desired page.
      navigate(policyId, appName) {
        const consoleBase = window.parent.location.href.replace(/\/console.*/, '/console')
        const path = appName ? `/apps/${policyId}/${appName}` : `/apps/${policyId}`
        window.parent.location.href = consoleBase + path
      },
    },
  }
</script>

<style scoped>
  .app-row {
    background-color: #fafafa;
  }
  .app-row td {
    border-top: none !important;
  }
  .status-dot {
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    flex-shrink: 0;
  }
</style>
