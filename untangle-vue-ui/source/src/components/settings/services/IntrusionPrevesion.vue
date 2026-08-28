<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-0`">
    <intrusion-prevention
      v-if="settings"
      ref="intrusionPrevention"
      :settings="settings"
      :app-data="consolidatedAppData"
      :is-installed="isInstalled"
      :is-expert-mode="isExpertMode"
      :tabs="allTabs"
      :metrics-data="formattedMetrics"
      :network-settings="networkSettings"
      :reports="appReports"
      :overview-data="overviewData"
      :memory-data="memoryData"
      :max-memory="maxMemory"
      :signatures="signatures"
      :signature-groups="signatureGroups"
      :home-networks="homeNetworks"
      :company-name="companyName"
      :loading-overview="loadingOverview"
      @toggle-state="toggleAppState"
      @update-signatures="onUpdateSignatures"
    >
      <template #actions="{ newSettings, isDirty }">
        <div v-if="isInstalled" class="d-flex flex-wrap align-center" style="gap: 8px">
          <div style="min-width: 140px">
            <u-app-status-remove
              class="mt-0"
              service-app
              :app-name="$t('intrusion_prevention')"
              @remove="onRemoveService"
            />
          </div>
          <v-divider vertical class="mx-4" />
          <u-btn @click="refreshData">{{ $t('refresh') }}</u-btn>
          <u-btn class="ml-2" :disabled="!isDirty" @click="setSettings(newSettings)">{{ $t('save') }}</u-btn>
        </div>
        <div v-else style="min-width: 180px">
          <u-app-install @install="onInstallService" />
        </div>
      </template>
    </intrusion-prevention>
  </v-container>
</template>

<script>
  import { mapGetters } from 'vuex'
  import {
    IntrusionPrevention,
    intrusionPreventionAllTabs,
    matchCondition,
    UAppStatusRemove,
    UAppInstall,
  } from 'vuntangle'
  import { ngfwCapabilities } from './ipCapabilities'
  import serviceMixin from './serviceMixin'
  import util from '@/util/util'
  import Util from '@/util/setupUtil'

  // Matches an IPv4 address with optional CIDR prefix, e.g. 192.168.1.0/24
  const ipv4NetworkRegex = /((\d{1,3}\.){3}\d{1,3})(\/(\d{1,2})|)/

  export default {
    components: {
      IntrusionPrevention,
      UAppStatusRemove,
      UAppInstall,
    },

    mixins: [serviceMixin],

    provide() {
      return {
        capabilities: ngfwCapabilities,
        $remoteData: () => ({
          interfaces: this.interfaces,
          networkVariables: this.networkVariables,
          defaultNetwork: this.defaultNetwork,
        }),
        $features: { hasRuleLogs: false, hasIpv6Support: false, hasLogAction: false, hideRuleIdColumn: true },
        $readOnly: false,
        $applications: null,
      }
    },

    data() {
      const now = Math.round(Date.now() / 1000) * 1000
      return {
        serviceName: 'intrusion-prevention',
        licenseNodeName: 'intrusion-prevention',
        displayNameFallback: 'Intrusion Prevention',
        overviewData: { daemonErrors: '', lastUpdate: '', lastUpdateCheck: '' },
        loadingOverview: false,
        memoryHistory: Array.from({ length: 7 }, (_, i) => ({ timestamp: now + (i - 6) * 10000, memory: 0 })),
        cachedSignatures: [],
        signatures: [],
        signatureGroups: {},
        companyName: '',
        homeNetworks: '',
        defaultNetwork: '',
      }
    },

    computed: {
      ...mapGetters('metrics', ['getAppMetric', 'lastUpdateTime', 'systemStats']),

      isExpertMode: ({ $store }) => $store.getters['config/isExpertMode'],

      networkSettings: ({ $store }) => $store.getters['config/networkSetting'],

      interfaces: ({ networkSettings }) => util.getInterfaceList(networkSettings, true, true),

      /**
       * Builds the list of network variable options for HOME_NET dropdowns.
       * Resolves $VAR references and filters to IPv4 network values only.
       * @returns {{ description: string, value: string, detail: string }[]}
       */
      networkVariables() {
        const items = [{ description: this.$t('recommended'), value: 'recommended', detail: '' }]
        const variablesList = this.settings?.variables || []
        const resolved = variablesList
          .map(variable => ({
            ...variable,
            detail: this.resolveVariableValue(variable, variablesList),
          }))
          .filter(variable => ipv4NetworkRegex.test(variable.detail))

        for (const variable of resolved) {
          items.push({
            description: `${variable.name} - ${variable.value}`,
            value: `$${variable.name}`,
            detail: variable.detail || variable.value,
          })
        }
        return items
      },

      iconPath: () => null,

      allTabs: () => intrusionPreventionAllTabs,

      memoryData() {
        return this.memoryHistory
      },

      maxMemory() {
        return this.systemStats?.MemTotal || 0
      },
    },

    watch: {
      lastUpdateTime(timestamp) {
        if (!this.consolidatedAppData?.powerState?.on || !this.instanceId) return
        const metric = this.getAppMetric(this.instanceId, 'memory')
        const memory = metric ? metric.value : 0
        this.memoryHistory = [...this.memoryHistory.slice(1), { timestamp, memory }]
      },
      'consolidatedAppData.powerState.on'(isOn) {
        if (!isOn) {
          const now = Math.round(Date.now() / 1000) * 1000
          this.memoryHistory = Array.from({ length: 7 }, (_, i) => ({ timestamp: now + (i - 6) * 10000, memory: 0 }))
        }
      },
      appManager(newVal, oldVal) {
        if (newVal && !oldVal) this.getSettings()
      },
      maxMemory(val) {
        if (val && this.cachedSignatures.length) {
          this.signatureGroups = this.buildGroups(this.cachedSignatures)
        }
      },
    },

    created() {
      this.$store.dispatch('config/getNetworkSettings', false)
    },

    methods: {
      setSettings(newSettings) {
        const prepared = {
          ...newSettings,
          signatures: (newSettings.signatures || []).map(sig => ({
            javaClass: sig.javaClass,
            signature: sig.signature,
            category: sig.category || 'custom',
          })),
        }
        this.saveSettings(prepared)
      },

      /** Reloads both app settings (license/state) and IPS-specific settings (status + signatures). */
      refreshData() {
        this.loadAppSettings()
        this.getSettings()
      },

      /** get Settings */
      async getSettings() {
        if (!this.appManager) return

        this.loadingOverview = true
        try {
          const [status, companyName] = await Promise.all([
            new Promise(resolve => {
              this.appManager.getAppStatus(result => resolve(result?.result ?? result))
            }),
            this.$store.dispatch('apps/getCompanyName'),
          ])

          this.companyName = companyName
          // homeNetworks drives HOME_NET resolution in networkVariables computed
          this.homeNetworks = status?.homeNetworks != null ? '[' + status.homeNetworks.join(', ') + ']' : ''
          this.defaultNetwork = status?.homeNetworks?.[0] ?? '192.168.1.0/24'

          this.overviewData = {
            lastUpdateCheck: util.formatTimestamp(status?.lastUpdateCheck),
            lastUpdate: util.formatTimestamp(status?.lastUpdate),
            daemonErrors: this.parseDaemonErrors(status?.errors),
          }
          this.cachedSignatures = []
          await this.onFetchSignatures()
        } catch (err) {
          Util.handleException(err)
        } finally {
          this.loadingOverview = false
        }
      },

      /**
       * Recursively expands $VAR references in a variable's value using the full variables list,
       * then delegates to processVariableValue for special-case handling (e.g. 'default').
       * @param {{ name: string, value: string }} variable
       * @param {{ name: string, value: string }[]} variablesList
       * @returns {string}
       */
      resolveVariableValue(variable, variablesList) {
        const varRegex = /\$([A-Za-z0-9_]+)/
        let expanded = variable.value

        let match
        do {
          match = varRegex.exec(expanded)
          if (match) {
            const ref = variablesList.find(v => v.name === match[1])
            if (ref) {
              expanded = expanded.replace(match[0], this.processVariableValue(match[1], ref.value))
            } else {
              break
            }
          }
        } while (match)

        return this.processVariableValue(variable.name, expanded)
      },

      /**
       * Replaces the 'default' sentinel with the runtime value for a variable.
       * For HOME_NET, the value is derived from homeNetworks populated by getSettings.
       * @param {string} name - variable name (e.g. 'HOME_NET')
       * @param {string} value - current value, possibly 'default'
       * @returns {string}
       */
      processVariableValue(name, value) {
        if (value !== 'default') return value
        if (name === 'HOME_NET') {
          return this.homeNetworks || ''
        }
        return 'unknown'
      },

      /**
       * Extracts the human-readable message portion from each Suricata daemon error log line.
       * Lines not matching the expected format are dropped.
       * @param {string|null} errors - newline-separated log output from app status
       * @returns {string} newline-joined error messages, or empty string if none
       */
      parseDaemonErrors(errors) {
        if (!errors) return ''
        const regex = /\] - (.*)$/
        return errors
          .split('\n')
          .map(line => {
            const m = regex.exec(line)
            return m ? m[1] : null
          })
          .filter(Boolean)
          .join('\n')
      },

      /**
       * Fetches and parses all Suricata signature sets from the backend.
       * Returns immediately from cache if signatures were already loaded this session.
       * Downloads the catalog first, then fetches each rule set sequentially,
       * populating this.signatures and this.signatureGroups when done.
       */
      async onFetchSignatures() {
        if (this.cachedSignatures.length) {
          this.signatures = this.cachedSignatures
          this.signatureGroups = this.buildGroups(this.cachedSignatures)
          this.lastUpdated = this.overviewData.lastUpdate
          return
        }

        let catalog = []
        const signatureSkips = []
        const signatures = []

        const download = arg5 =>
          fetch('/admin/download', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({
              type: 'IntrusionPreventionSettings',
              arg1: 'signatures',
              arg2: this.instanceId || '',
              arg5,
            }).toString(),
          }).then(r => r.text())

        try {
          catalog = (await download('catalog')).split('\n').filter(Boolean)

          for (let i = 0; i < catalog.length; i++) {
            const setName = catalog[i]
            if (!setName.trim()) continue

            try {
              const text = await download(setName)
              signatures.push(...this.buildSignatures(text, setName))
            } catch (err) {
              Util.handleException(err)
              signatureSkips.push(setName)
            }
          }

          const customSigs = this.settings?.signatures || []
          customSigs.forEach(sig => {
            if (!sig.signature) return
            const parsed = this.buildSignatures(sig.signature, sig.category || 'custom')
            if (parsed.length) {
              parsed[0].reserved = false
              parsed[0].default = false
              signatures.push(parsed[0])
            }
          })

          signatures.sort((a, b) => Number(a.sid) - Number(b.sid))
          this.cachedSignatures = signatures
          this.signatures = signatures
          this.signatureGroups = this.buildGroups(signatures)
          this.lastUpdated = this.overviewData.lastUpdate
        } catch (err) {
          Util.handleException(err)
        }
      },

      // Groups a signatures array by classtype, computing ruleAction for each entry.
      // Called once after fetch so SignaturesTab receives pre-computed groups and opens instantly.
      buildGroups(signatures) {
        const ipRules = this.settings?.ip_rules || []
        const cache = Object.create(null)
        const systemMemoryBytes = this.maxMemory || 0

        const resolveRuleActionKey = sig => {
          const recommendedAction = (sig.recommendedAction || sig.action || 'log').toLowerCase()
          const cacheKey = `${sig.sid}|${sig.gid}`
          if (cacheKey in cache) return cache[cacheKey]

          let result = 'disable'
          const ruleTrace = []
          for (const rule of ipRules) {
            if (!rule.enabled) continue
            const actionType = rule.action?.type
            if (actionType === 'IPS_WHITELIST') continue

            const conditions = rule.conditions || []
            const failedConds = conditions.filter(cond => !matchCondition(cond, sig, systemMemoryBytes))
            const allMatch = failedConds.length === 0
            if (!allMatch) {
              ruleTrace.push({ actionType, failedConds })
              continue
            }

            switch (actionType) {
              case 'IPS_DEFAULT':
                result = recommendedAction
                break
              case 'IPS_BLOCKLOG':
                result = recommendedAction === 'log' || recommendedAction === 'block' ? 'block' : 'disable'
                break
              case 'IPS_LOG':
                result = 'log'
                break
              case 'IPS_BLOCK':
                result = 'block'
                break
              case 'IPS_DISABLE':
                result = 'disable'
                break
              default:
                result = recommendedAction
            }
            cache[cacheKey] = result
            return result
          }
          cache[cacheKey] = result
          return result
        }

        const raw = {}
        signatures.forEach((sig, sigIdx) => {
          const ruleActionKey = resolveRuleActionKey(sig)
          const ruleAction = this.recommendedActionLabel(ruleActionKey)
          const enriched = Object.freeze({ ...sig, ruleAction, ruleActionKey, _sigIndex: sigIdx })
          const key = sig.classtype || 'other'
          if (!raw[key]) raw[key] = []
          raw[key].push(enriched)
        })

        const sorted = {}
        Object.keys(raw)
          .sort()
          .forEach(key => {
            const allItems = Object.freeze(raw[key])
            sorted[key] = { expanded: false, allItems, items: [...allItems] }
          })
        return sorted
      },

      recommendedActionLabel(action) {
        switch (action) {
          case 'log':
            return this.$vuntangle.$t('log')
          case 'block':
            return this.$vuntangle.$t('block')
          case 'disable':
            return this.$vuntangle.$t('disable')
          default:
            return action
        }
      },

      onUpdateSignatures({ cb }) {
        this.appManager.updateSignatureManual(result => {
          const updateSuccess = result?.updateSuccess === true
          if (updateSuccess) {
            this.$vuntangle.toast.add(this.$vuntangle.$t('ips_adv_update_signatures_success'))
            this.cachedSignatures = []
            this.onFetchSignatures()
          } else {
            this.$vuntangle.toast.add(this.$vuntangle.$t('ips_adv_update_signatures_fail'), 'error')
          }
          cb()
        })
      },

      /**
       * Parse raw Suricata rules text into signature objects.
       * Replicates the ExtJS signature model constructor + buildSignatures logic.
       */
      buildSignatures(text, defaultCategory = 'misc') {
        const filenameRegex = /^# filename: (?:emerging-)?(.+)\.rules$/
        const signatureRegex =
          /^([#\s]*)(alert|log|pass|activate|dynamic|drop|reject|sdrop)\s+(?:([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+(->|<>)\s+([^\s]+)\s+([^\s]+)\s+)?\((.+)\)/

        const signatures = []
        let category = defaultCategory

        const getOption = (optionsStr, key) => {
          const quotedMatch = new RegExp(`\\b${key}:"([^"]*)"\\s*(?:;|$)`).exec(optionsStr)
          if (quotedMatch) return quotedMatch[1]
          const unquotedMatch = new RegExp(`\\b${key}:([^;]+?)\\s*(?:;|$)`).exec(optionsStr)
          return unquotedMatch ? unquotedMatch[1].trim() : ''
        }

        for (const line of text.split('\n')) {
          const trimmed = line.trim()
          if (!trimmed) continue

          const filenameMatch = filenameRegex.exec(trimmed)
          if (filenameMatch) {
            category = filenameMatch[1]
            continue
          }

          const match = signatureRegex.exec(trimmed)
          if (!match) continue

          const [
            ,
            prefix,
            rawAction,
            protocol = '',
            src_ip = '',
            src_port = '',
            direction = '',
            dst_ip = '',
            dst_port = '',
            optionsStr = '',
          ] = match

          let action
          if (prefix === '#') action = 'disable'
          else if (rawAction === 'alert' || rawAction === 'log' || rawAction === 'drop' || rawAction === 'sdrop')
            action = 'log'
          else if (rawAction === 'reject') action = 'block'
          else action = 'log'

          signatures.push({
            sid: getOption(optionsStr, 'sid'),
            gid: getOption(optionsStr, 'gid') || '1',
            msg: getOption(optionsStr, 'msg'),
            classtype: getOption(optionsStr, 'classtype') || 'general',
            protocol,
            src_ip,
            src_port,
            direction,
            dst_ip,
            dst_port,
            category,
            action,
            signature: trimmed,
            reserved: true,
            default: true,
          })
        }

        return signatures
      },
    },
  }
</script>
