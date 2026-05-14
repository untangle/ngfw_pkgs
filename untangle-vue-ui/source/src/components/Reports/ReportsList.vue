<template>
  <reports :features="features" :cards="displayCards" :reports="reports" @view-report="onViewReport">
    <!-- Export All Reports button in page header -->
    <template #page-actions>
      <v-tooltip bottom>
        <template #activator="{ on, attrs }">
          <u-btn v-bind="attrs" v-on="on" @click="exportAllReports">
            <v-icon left small>mdi-download</v-icon>
            Export All Reports
          </u-btn>
        </template>
        <span>Export all report configurations as JSON</span>
      </v-tooltip>
    </template>

    <!-- Global toolbar: Search, Conditions, Import -->
    <template #toolbar>
      <div class="d-flex align-center mb-4" style="gap: 12px">
        <v-text-field
          v-model="search"
          dense
          outlined
          hide-details
          clearable
          prepend-inner-icon="mdi-magnify"
          placeholder="Search reports..."
          style="max-width: 280px"
        />
        <v-menu offset-y>
          <template #activator="{ on, attrs }">
            <u-btn small v-bind="attrs" v-on="on">
              <v-icon left small>mdi-filter-outline</v-icon>
              Add Conditions
              <v-icon right small>mdi-chevron-down</v-icon>
            </u-btn>
          </template>
          <v-list dense>
            <v-list-item v-for="col in conditionColumns" :key="col.value" @click="onAddCondition(col.value)">
              <v-list-item-title>{{ col.text }}</v-list-item-title>
            </v-list-item>
            <v-divider />
            <v-list-item @click="onMoreConditions">
              <v-list-item-title><strong>More conditions...</strong></v-list-item-title>
            </v-list-item>
          </v-list>
        </v-menu>

        <v-menu offset-y>
          <template #activator="{ on, attrs }">
            <u-btn small v-bind="attrs" v-on="on">
              <v-icon left small>mdi-plus-circle-outline</v-icon>
              Add/Import
              <v-icon right small>mdi-chevron-down</v-icon>
            </u-btn>
          </template>
          <v-list dense>
            <v-list-item @click="onCreateNew">
              <v-list-item-title>Create New</v-list-item-title>
            </v-list-item>
            <v-list-item @click="onImport">
              <v-list-item-title>Import</v-list-item-title>
            </v-list-item>
          </v-list>
        </v-menu>
      </div>
    </template>

    <!-- Maximize icon and Export icon in each card title -->
    <template #card-title-append="{ categoryKey }">
      <v-spacer />
      <v-tooltip bottom>
        <template #activator="{ on, attrs }">
          <v-btn icon x-small v-bind="attrs" v-on="on" @click="exportCategoryReports(categoryKey)">
            <v-icon small>mdi-download</v-icon>
          </v-btn>
        </template>
        <span>Export {{ categoryKey }} Reports</span>
      </v-tooltip>
      <v-tooltip bottom class="ml-1">
        <template #activator="{ on, attrs }">
          <v-btn icon x-small class="ml-1" v-bind="attrs" v-on="on" @click="toggleMaximize(categoryKey)">
            <v-icon small>{{ maximizedCategory === categoryKey ? 'mdi-fullscreen-exit' : 'mdi-fullscreen' }}</v-icon>
          </v-btn>
        </template>
        <span>{{ maximizedCategory === categoryKey ? 'Minimize' : 'Maximize' }}</span>
      </v-tooltip>
    </template>

    <!-- View More / View Less toggle below each card list -->
    <template #card-footer="{ card, isExpanded, toggle }">
      <div v-if="card.length > 3" class="px-2 pb-2">
        <v-btn text x-small class="primary--text" @click="toggle">
          {{ isExpanded ? 'View Less' : 'View More' }}
        </v-btn>
      </div>
    </template>

    <!-- Maximized category: full-width card showing all reports -->
    <template v-if="maximizedCategory" #append>
      <v-card outlined>
        <v-card-title :class="`py-0 subtitle-1 ${$vuntangle.theme === 'dark' ? '' : 'primary--text'}`">
          <span class="py-2 font-weight-medium">{{ maximizedCategory }}</span>
          <v-spacer />
          <v-tooltip bottom>
            <template #activator="{ on, attrs }">
              <v-btn icon x-small v-bind="attrs" v-on="on" @click="exportCategoryReports(maximizedCategory)">
                <v-icon small>mdi-download</v-icon>
              </v-btn>
            </template>
            <span>Export {{ maximizedCategory }} Reports</span>
          </v-tooltip>
          <v-tooltip bottom class="ml-1">
            <template #activator="{ on, attrs }">
              <v-btn icon x-small class="ml-1" v-bind="attrs" v-on="on" @click="toggleMaximize(maximizedCategory)">
                <v-icon small>mdi-fullscreen-exit</v-icon>
              </v-btn>
            </template>
            <span>Minimize</span>
          </v-tooltip>
        </v-card-title>
        <v-row class="ma-0">
          <v-col v-for="view in cards[maximizedCategory]" :key="view.id" cols="12" sm="6" md="4" class="pa-0">
            <v-list dense class="pa-0">
              <v-list-item @click="onViewReport(view.id)">
                <v-list-item-content>
                  <v-list-item-title>{{ view.name }}</v-list-item-title>
                  <v-list-item-subtitle class="font-weight-regular caption" style="white-space: unset">
                    <span v-for="reportId in view.reports" :key="reportId" class="mr-4">
                      <v-icon small>{{ reports[reportId].icon }}</v-icon>
                      {{ reports[reportId].title }}
                    </span>
                  </v-list-item-subtitle>
                </v-list-item-content>
              </v-list-item>
            </v-list>
          </v-col>
        </v-row>
      </v-card>
    </template>
  </reports>
</template>

<script>
  import {
    VBtn,
    VCard,
    VCardTitle,
    VCol,
    VDivider,
    VIcon,
    VList,
    VListItem,
    VListItemContent,
    VListItemSubtitle,
    VListItemTitle,
    VMenu,
    VRow,
    VSpacer,
    VTextField,
    VTooltip,
  } from 'vuetify/lib'
  import { Reports } from 'vuntangle'
  import { urlEncode } from '@/util/reports'

  export default {
    components: {
      Reports,
      VBtn,
      VCard,
      VCardTitle,
      VCol,
      VDivider,
      VIcon,
      VList,
      VListItem,
      VListItemContent,
      VListItemSubtitle,
      VListItemTitle,
      VMenu,
      VRow,
      VSpacer,
      VTextField,
      VTooltip,
    },

    data() {
      return {
        features: {},
        search: '',
        maximizedCategory: null,
        conditionColumns: [
          { text: 'Username', value: 'username' },
          { text: 'Protocol', value: 'protocol' },
          { text: 'Hostname', value: 'hostname' },
          { text: 'Client', value: 'c_client_addr' },
          { text: 'Server', value: 's_server_addr' },
          { text: 'Server Port', value: 's_server_port' },
          { text: 'Policy Id', value: 'policy_id' },
        ],
      }
    },

    computed: {
      cards: ({ $store }) => $store.getters['reports/cardItems'],
      reports: ({ $store }) => $store.getters['reports/reportsLookup'],
      displayCards({ cards, maximizedCategory }) {
        if (maximizedCategory) return {}
        return cards
      },
    },

    methods: {
      toggleMaximize(categoryKey) {
        this.maximizedCategory = this.maximizedCategory === categoryKey ? null : categoryKey
      },

      onViewReport(uniqueId) {
        const entry = this.$store.getters['reports/allReports'].find(r => r.uniqueId === uniqueId)
        if (!entry) return
        this.$router.push(`/reports/${urlEncode(entry.category)}/${urlEncode(entry.title)}`)
      },

      onAddCondition() {
        // TODO: apply condition for column
      },

      onMoreConditions() {
        // TODO: open More Conditions dialog
      },

      onCreateNew() {
        // TODO: open blank report entry form
      },

      onImport() {
        // TODO: open Import dialog
      },

      exportAllReports() {
        this._downloadReports(this.$store.getters['reports/allReports'], 'AllReports')
      },

      exportCategoryReports(categoryKey) {
        const reports = this.$store.state.reports.reportsByCategory[categoryKey] || []
        this._downloadReports(reports, `AllReports_${categoryKey.replace(/ /g, '_')}`)
      },

      _downloadReports(reports, filename) {
        const internalFields = ['localizedTitle', 'localizedDescription', 'slug', 'categorySlug', 'url', 'icon']
        const cleaned = reports.map(r => {
          const rep = { ...r }
          internalFields.forEach(f => delete rep[f])
          return rep
        })

        const blob = new Blob([JSON.stringify(cleaned, null, 2)], { type: 'application/json' })
        const url = URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `${filename}.json`
        a.click()
        URL.revokeObjectURL(url)
      },
    },
  }
</script>
