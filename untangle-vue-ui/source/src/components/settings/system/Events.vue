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
            <EventRulesList
              rule-type="alert"
              :settings="eventSettings"
              @settings-change="onSettingsChange"
            ></EventRulesList>
          </v-tab-item>
          <v-tab-item> </v-tab-item>
          <v-tab-item> </v-tab-item>
          <v-tab-item>
            <EmailTemplate
              ref="emailTemplate"
              :settings="eventSettings"
              :template-parameters="templateParameters"
              :email-template-defaults="defaultEmailSettings"
              @default-email-settings="getDefaultEmailSettings"
              @email-alert-format="getEmailAlertFormat"
              @settings-change="onSettingsChange"
            />
          </v-tab-item>
        </v-tabs-items>
      </div>
    </div>
  </v-container>
</template>
<script>
  import { VTabsItems, VTabItem, VContainer, VSpacer } from 'vuetify/lib'
  import { cloneDeep, isEqual } from 'lodash'
  import { EmailTemplate } from 'vuntangle'
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
      }
    },

    computed: {
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
      this.processEventData()
    },

    methods: {
      processEventData() {
        try {
          const classFields = {}
          const classes = []

          Object.keys(this.classFields).forEach(className => {
            const classInfo = this.classFields[className]

            classes.push([className, classInfo.description])

            const conditions = []
            const conditionsOrder = []

            classInfo.fields.forEach(field => {
              const fieldNames = field.name?.split('.') || []
              const ignoreFieldName = fieldNames[fieldNames.length - 1]

              if (ignoreFieldName === 'class' || ignoreFieldName === 'timeStamp') {
                return
              }

              // Default display name
              if (field.name) {
                field.displayName = field.name
              }

              // Field type normalization
              if (field.values) {
                field.type = 'select'
                field.comparator = 'boolean'
              } else {
                switch ((field.type || '').toLowerCase()) {
                  case 'boolean':
                    field.type = 'boolean'
                    field.comparator = 'boolean'
                    field.values = [
                      [true, this.$t('true')],
                      [false, this.$t('false')],
                    ]
                    break

                  case 'double':
                  case 'float':
                  case 'integer':
                  case 'int':
                  case 'long':
                  case 'short':
                    field.type = 'number'
                    field.comparator = 'numeric'
                    break

                  default:
                    field.type = 'text'
                    field.comparator = 'text'
                }
              }

              // Clone default condition & merge
              const newCondition = {
                ...cloneDeep(this.defaultCondition),
                ...field,
              }

              conditions[newCondition.name] = newCondition
              conditionsOrder.push(newCondition.name)
            })

            classFields[className] = {
              description: classInfo.description,
              conditions,
              conditionsOrder,
            }
          })

          const allClassFields = {
            ...cloneDeep(classFields),
            All: {
              description: this.$t('match_all_cases'),
              conditions: [],
              conditionsOrder: [],
            },
          }

          const allClasses = [...classes, ['All', allClassFields.All.description]]

          this.processedClassFields = classFields
          this.allClassFields = allClassFields

          this.classes = classes.sort((a, b) => a[0].localeCompare(b[0]))
          this.allClasses = allClasses.sort((a, b) => a[0].localeCompare(b[0]))

          this.targetFields = []
          this.templateUnmatched = ''

          this.syslogServersGridEmpty = !(this.eventSettings?.syslogServers?.list?.length > 0)
        } catch (err) {
          Util.handleException(err)
        }
      },
      /**
       * Handler when using grid 'Refresh' action
       */
      onRefreshSettings() {
        this.loadEvents(true)
        this.processEventData()
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
      onSettingsChange(updatedSettings) {
        this.settingsCopy = updatedSettings
      },

      /**
       * Save the settings to the store
       * @param {object} newSettings - The settings object to save
       */
      async onSaveSettings(newSettings) {
        const isValid = await this.$refs.emailTemplate.validate()
        if (!isValid) return
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
        this.processEventData()
      },
    },
  }
</script>
