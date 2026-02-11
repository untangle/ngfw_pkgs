<template>
  <v-container fluid class="d-flex flex-column flex-grow-1 pa-2">
    <div class="d-flex align-center">
      <v-spacer />
      <u-btn @click="onRefreshSettings">{{ $t('refresh') }}</u-btn>
      <u-btn class="ml-2" :disabled="!isDirty" @click="onSaveSettings(settingsCopy)">{{ $t('save') }}</u-btn>
    </div>
    <div class="d-flex flex-column">
      <v-spacer />
      <div class="flex-shrink-1">
        <v-tabs v-model="selectedTab" class="mb-4">
          <v-tab>
            {{ $vuntangle.$t('alerts') }}
          </v-tab>
          <v-tab>
            {{ $vuntangle.$t('triggers') }}
          </v-tab>
          <v-tab>
            {{ $vuntangle.$t('syslog') }}
          </v-tab>
          <v-tab>
            {{ $vuntangle.$t('email_template') }}
          </v-tab>
        </v-tabs>
        <!-- Tab Content -->
        <v-tabs-items v-model="selectedTab">
          <v-tab-item>
            <ValidationObserver ref="alertRulesList">
              <EventRulesList
                rule-type="alert"
                :settings="eventSettings"
                @settings-change="onSettingsChange($event, 'alerts')"
              />
            </ValidationObserver>
          </v-tab-item>
          <v-tab-item>
            <ValidationObserver ref="triggerRulesList">
              <EventRulesList
                rule-type="trigger"
                :settings="eventSettings"
                @settings-change="onSettingsChange($event, 'triggers')"
              />
            </ValidationObserver>
          </v-tab-item>
          <v-tab-item>
            <ValidationObserver ref="sysLog">
              <SysLog
                ref="syslog"
                :settings="eventSettings"
                :used-syslog-server-ids="usedSyslogServerIds"
                @settings-change="onSettingsChange($event, 'syslog')"
                v-on="$listeners"
              />
              <h3 class="font-weight-regular mt-2 mb-2 pa-2">{{ $vuntangle.$t('rules') }}</h3>
              <EventRulesList
                rule-type="syslog"
                :settings="eventSettings"
                :disable-rules="disableSyslogRules"
                @settings-change="onSettingsChange($event, 'syslog')"
              />
            </ValidationObserver>
          </v-tab-item>
          <v-tab-item>
            <ValidationObserver ref="emailtemplate">
              <EmailTemplate
                ref="emailTemplate"
                :settings="eventSettings"
                :template-parameters="templateParameters"
                :email-template-defaults="defaultEmailSettings"
                @default-email-settings="getDefaultEmailSettings"
                @email-alert-format="getEmailAlertFormat"
                @settings-change="onSettingsChange($event, 'email_template')"
              />
            </ValidationObserver>
          </v-tab-item>
        </v-tabs-items>
      </div>
    </div>
  </v-container>
</template>
<script>
  import { VTabsItems, VTabItem, VContainer, VSpacer } from 'vuetify/lib'
  import { cloneDeep, isEqual } from 'lodash'
  import { EmailTemplate, SysLog } from 'vuntangle'
  import EventRulesList from '../rules/EventRulesList.vue'
  import Util from '@/util/setupUtil'

  export default {
    components: {
      VContainer,
      VSpacer,
      VTabsItems,
      VTabItem,
      EventRulesList,
      EmailTemplate,
      SysLog,
    },

    data() {
      return {
        selectedTab: 0,
        settingsCopy: null,
        allClasses: [],
        allClassFields: {},
        processedClassFields: {},
        templateUnmatched: '',
        defaultCondition: {
          name: 'name',
          displayName: 'name',
          type: 'textfield',
          comparator: 'invert',
          visible: true,
          allowMultiple: false,
        },
        tabs: [
          { key: 'alertRulesList', valid: true },
          { key: 'triggerRulesList', valid: true },
          { key: 'sysLog', valid: true },
          { key: 'emailTemplate', valid: true },
        ],
      }
    },

    computed: {
      // array of syslog server ids used in syslog rules
      usedSyslogServerIds() {
        const rules = this.settingsCopy?.syslog_rules || []
        const usedIds = new Set()

        rules.forEach(rule => {
          const ids = rule?.action?.syslogServers || []
          ids.forEach(id => usedIds.add(id))
        })
        return Array.from(usedIds)
      },

      // disable syslog rules tab if no syslog servers are defined or modified
      disableSyslogRules() {
        const original = this.eventSettings?.syslogServers || []
        const modified = this.settingsCopy?.syslogServers || []

        // empty syslog servers
        if (modified.length === 0) {
          return true
        }

        // modified syslog servers
        if (!isEqual(original, modified)) {
          return true
        }

        return false
      },
      // the event settings from the store
      eventSettings: ({ $store }) => $store.getters['config/eventSettings'],
      classFields: ({ $store }) => $store.getters['config/classFieldsData'],
      templateParameters: ({ $store }) => $store.getters['config/templateParameters'],
      defaultEmailSettings: ({ $store }) => $store.getters['config/defaultEmailSettings'],
      isDirty() {
        if (!this.settingsCopy || !this.eventSettings) {
          return false
        }

        const normalize = settings => ({
          ...settings,
          emailSubject: settings.emailSubject ?? this.defaultEmailSettings.emailSubject,
          emailBody: settings.emailBody ?? this.defaultEmailSettings.emailBody,
          emailConvert: settings.emailConvert,
        })

        return !isEqual(normalize(this.eventSettings), normalize(this.settingsCopy))
      },
    },

    watch: {
      /**
       * settings watcher firing only once and only when incoming settings are undefined
       */
      eventSettings: {
        immediate: true,
        handler(eventSettings) {
          // must clone settings
          this.settingsCopy = eventSettings ? cloneDeep(eventSettings) : undefined
        },
      },
    },

    async created() {
      await this.loadEvents(false)
    },

    methods: {
      /**
       * Handler when using grid 'Refresh' action
       */
      onRefreshSettings() {
        this.loadEvents(true)
      },

      /**
       * Fetches the settings and updates the store.
       * If refetch is true, it forces a re-fetch of the settings.
       * @param {boolean} refetch - Whether to force a re-fetch of the settings.
       */
      async loadEvents(refetch) {
        this.$store.commit('SET_LOADER', true)
        await Promise.all([
          this.$store.dispatch('config/getEventSettings', refetch),
          this.$store.dispatch('config/getTemplateParameters', refetch),
          this.$store.dispatch('config/getClassFieldsData'),
          this.$store.dispatch('config/getDefaultEmailSettings', refetch),
        ]).finally(() => this.$store.commit('SET_LOADER', false))
      },

      getDefaultEmailSettings(cb) {
        const response = cloneDeep(this.$store.getters['config/defaultEmailSettings'])
        cb(response ?? null)
      },

      async getEmailAlertFormat(alertRule, event, templateEmailSubject, templateEmailBody, emailConvert, cb) {
        try {
          const response = await window.rpc.eventManager.emailAlertFormatPreview(
            alertRule,
            event,
            templateEmailSubject,
            templateEmailBody,
            emailConvert,
          )
          cb(response ?? null)
        } catch (e) {
          Util.handleException(e)
        }
      },

      /**
       * Update the local settings copy
       * @param {object} updatedSettings - The updated settings object
       * @param {boolean} isDirty - Whether the settings have changed
       */
      onSettingsChange(updatedSettings, tabName) {
        if (tabName === 'alerts') this.settingsCopy.alert_rules = updatedSettings.alert_rules
        else if (tabName === 'triggers') this.settingsCopy.trigger_rules = updatedSettings.trigger_rules
        else if (tabName === 'syslog') {
          this.settingsCopy.syslogServers = updatedSettings.syslogServers
            ? updatedSettings.syslogServers.map(s => ({ ...s }))
            : []

          this.settingsCopy.syslog_rules = updatedSettings.syslog_rules ? updatedSettings.syslog_rules : []
          // Add other syslog related settings change here
        } else {
          this.settingsCopy.emailSubject = updatedSettings.emailSubject
          this.settingsCopy.emailBody = updatedSettings.emailBody
          this.settingsCopy.emailConvert = updatedSettings.emailConvert
        }
      },

      /**
       * Save the settings to the store
       * @param {object} newSettings - The settings object to save
       */
      async onSaveSettings(newSettings) {
        // validate all tabs before saving and return to invalid tab
        if (await !this.validate()) return
        if (this.$refs.emailTemplate) {
          const isValid = await this.$refs.emailTemplate.validate()
          if (!isValid) return
        }
        this.$store.commit('SET_LOADER', true)
        await this.$store.dispatch('config/setEventSettings', newSettings)
        await Promise.all([
          this.$store.dispatch('config/getTemplateParameters', true),
          this.$store.dispatch('config/getClassFieldsData'),
          this.$store.dispatch('config/getDefaultEmailSettings', true),
        ]).finally(() => this.$store.commit('SET_LOADER', false))
      },

      /**
       * Optional hook triggered on browser refresh. refetches the settings.
       */
      onBrowserRefresh() {
        this.loadEvents(true)
      },

      /**
       * validate all tabs before saving
       */
      async validate() {
        const isValid = await Util.validateTabs({
          tabs: this.tabs,
          refs: this.$refs,
        })

        // If any tab is invalid, switch to the first invalid one
        if (!isValid) {
          const invalidIndex = this.tabs.findIndex(tab => tab.valid === false)
          if (invalidIndex !== -1) {
            this.selectedTab = invalidIndex
          }
        }

        return isValid
      },
    },
  }
</script>
