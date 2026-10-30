<template>
  <v-container fluid class="dashboard-page">
    <div class="dashboard-layout">
      <aside v-if="managerVisible" class="dashboard-manager">
        <div class="dashboard-manager__toolbar">
          <v-menu offset-y>
            <template #activator="{ on, attrs }">
              <u-btn
                color="primary"
                :min-width="null"
                class="dashboard-manager__widgets-button"
                v-bind="attrs"
                v-on="on"
              >
                <v-icon small class="mr-2">mdi-cog</v-icon>
                {{ $t('widgets') }}
                <v-icon small class="ml-2">mdi-menu-down</v-icon>
              </u-btn>
            </template>
            <v-list dense>
              <v-list-item @click="openImportDialog">
                <v-icon small class="mr-2">mdi-download</v-icon>
                <v-list-item-title>{{ $t('import') }}</v-list-item-title>
              </v-list-item>
              <v-list-item @click="exportWidgets">
                <v-icon small class="mr-2">mdi-upload</v-icon>
                <v-list-item-title>{{ $t('export') }}</v-list-item-title>
              </v-list-item>
              <v-divider />
              <v-menu offset-x open-on-hover>
                <template #activator="{ on, attrs }">
                  <v-list-item v-bind="attrs" v-on="on">
                    <v-icon small class="mr-2">mdi-plus-circle</v-icon>
                    <v-list-item-title>{{ $t('add_common_widgets') }}</v-list-item-title>
                    <v-icon small>mdi-chevron-right</v-icon>
                  </v-list-item>
                </template>
                <v-list dense>
                  <v-list-item
                    v-for="option in commonWidgetOptions"
                    :key="option.type"
                    @click="addCommonWidget(option.type)"
                  >
                    <v-list-item-title>{{ $t(option.label) }}</v-list-item-title>
                  </v-list-item>
                </v-list>
              </v-menu>
              <v-list-item @click="createReportWidget">
                <v-icon small class="mr-2">mdi-chart-areaspline</v-icon>
                <v-list-item-title>{{ $t('create_new_report_widget') }} </v-list-item-title>
              </v-list-item>
              <v-divider />
              <v-list-item @click="enableReordering">
                <v-icon small class="mr-2">mdi-sort</v-icon>
                <v-list-item-title>{{ $t('reorder') }}</v-list-item-title>
              </v-list-item>
              <v-list-item @click="resetDashboard">
                <v-icon small class="mr-2">mdi-restore</v-icon>
                <v-list-item-title>{{ $t('reset_to_defaults') }}</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-menu>
          <v-spacer />
          <v-btn icon small @click="cancelSettings">
            <v-icon small>mdi-close</v-icon>
          </v-btn>
        </div>

        <v-list dense class="dashboard-manager__list">
          <draggable
            v-model="managerWidgets"
            tag="div"
            handle=".dashboard-manager__drag-handle"
            :disabled="!reorderingWidgets"
          >
            <v-list-item
              v-for="(widget, index) in managerWidgets"
              :key="widget._dashboardKey"
              :class="{ 'dashboard-manager__widget--marked-for-delete': widget.markedForDelete }"
            >
              <v-list-item-action v-if="reorderingWidgets" class="my-0 dashboard-manager__order-cell">
                <v-icon small class="dashboard-manager__drag-handle">mdi-drag-horizontal</v-icon>
              </v-list-item-action>
              <v-list-item-action class="my-0">
                <v-checkbox
                  v-model="widget.enabled"
                  :disabled="!isSupportedWidget(widget)"
                  hide-details
                  dense
                  class="mt-0"
                  @change="saveWidgetSettings(widget)"
                />
              </v-list-item-action>
              <v-list-item-content>
                <v-list-item-title>{{ widgetTitle(widget) }}</v-list-item-title>
                <v-list-item-subtitle v-if="!isSupportedWidget(widget)">
                  {{ $t('no_data_available') }}
                </v-list-item-subtitle>
              </v-list-item-content>
              <v-list-item-action class="my-0">
                <v-btn icon x-small :disabled="!isSupportedWidget(widget)" @click="removeWidget(index)">
                  <v-icon small :color="widget.markedForDelete ? 'error' : 'grey'">mdi-trash-can-outline</v-icon>
                </v-btn>
              </v-list-item-action>
            </v-list-item>
            <v-list-item v-if="!managerWidgets.length">
              <v-list-item-content>
                <v-list-item-title>{{ $t('no_data') }}</v-list-item-title>
              </v-list-item-content>
            </v-list-item>
          </draggable>
        </v-list>

        <div class="dashboard-manager__actions">
          <u-btn text :min-width="null" @click="cancelSettings">{{ $t('cancel') }}</u-btn>
          <u-btn color="primary" :min-width="null" :loading="savingSettings" @click="applySettings">
            {{ $t('apply') }}
          </u-btn>
        </div>
      </aside>

      <report-widget-dialog
        :show-dialog="reportWidgetDialog"
        :categories="reportCategories"
        :reports="allReports"
        :supported-report-ids="supportedReportIds"
        :initial-report-id="supportedReportIds[0]"
        :build-report-view="buildReportViewForWidget"
        @add="addReportWidget"
        @close="closeReportWidgetDialog"
        @fetch-data="onFetchData"
      />

      <main class="dashboard-content">
        <div class="dashboard-toolbar">
          <u-btn
            v-if="!managerVisible"
            color="primary"
            :min-width="null"
            class="dashboard-toolbar__button dashboard-toolbar__settings"
            @click="openSettings"
          >
            <v-icon small class="mr-2">mdi-cog</v-icon>
            {{ $t('settings') }}
          </u-btn>

          <div class="dashboard-toolbar__conditions">
            <conditions-filter
              @add-condition="onAddCondition"
              @remove-condition="onRemoveCondition"
              @clear-conditions="onClearConditions"
              @set-conditions="onSetConditions"
            />
          </div>

          <v-menu offset-y>
            <template #activator="{ on, attrs }">
              <u-btn
                color="primary"
                :min-width="null"
                class="dashboard-toolbar__button dashboard-toolbar__since"
                v-bind="attrs"
                v-on="on"
              >
                <v-icon small class="mr-2">mdi-clock-outline</v-icon>
                {{ $t(since) }}
                <v-icon small class="ml-2">mdi-menu-down</v-icon>
              </u-btn>
            </template>
            <v-list dense>
              <v-list-item v-for="option in sinceOptions" :key="option.value" @click="updateSince(option)">
                <v-list-item-title>{{ $t(option.text) }}</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-menu>
        </div>

        <grid-layout
          :key="dashboardLayoutKey"
          :layout.sync="baseLayout"
          :responsive-layouts.sync="responsiveLayouts"
          :row-height="300"
          :margin="[16, 16]"
          :use-css-transforms="false"
          :is-resizable="false"
          :is-draggable="false"
          vertical-compact
          responsive
          :breakpoints="$vuntangle.widgets.breakpoints"
          :cols="$vuntangle.widgets.gridSizes"
        >
          <grid-item
            v-for="widget in baseLayout"
            :key="widget.i"
            :x="widget.x"
            :y="widget.y"
            :w="widget.w"
            :h="widget.h"
            :i="widget.i"
          >
            <component
              :is="widget.cmp"
              v-if="
                ['Information', 'Resources', 'NetworkLayout'].includes(widget.cmp) && getLayoutWidgetDefinition(widget)
              "
              v-bind="getLayoutWidgetProps(widget)"
            />
            <u-widget
              v-else-if="getLayoutWidgetDefinition(widget)"
              :title="widgetTitle(getLayoutWidgetWidget(widget))"
              :enable-expand="false"
            />
          </grid-item>
        </grid-layout>
      </main>
    </div>
  </v-container>
</template>
<script>
  import { GridLayout, GridItem } from 'vue-grid-layout'
  import VueDraggable from 'vuedraggable'
  import cloneDeep from 'lodash/cloneDeep'
  import { mapGetters } from 'vuex'
  import { UWidget } from 'vuntangle'
  import ConditionsFilter from '../../../node_modules/vuntangle/src/shared/Reports/components/ConditionsFilter.vue'
  import {
    Information,
    Resources,
    CpuLoad,
    NetworkInformation,
    NetworkLayout,
    MapDistribution,
    PolicyOverview,
    Notifications,
    ReportWidget,
  } from '../widgets'
  import reportsMixin from '../reports/reportsMixin'
  import DashboardImportDialog from './DashboardImportDialog.vue'
  import ReportWidgetDialog from './ReportWidgetDialog.vue'
  import { buildReportView as buildReportViewConfig } from '@/util/reportViews'
  import { removeDashboardLayout, widgetComponents } from '@/util/widgets'

  export default {
    name: 'Dashboard',
    components: {
      ConditionsFilter,
      draggable: VueDraggable,
      GridLayout,
      GridItem,
      UWidget,
      Information,
      Resources,
      CpuLoad,
      NetworkInformation,
      NetworkLayout,
      MapDistribution,
      PolicyOverview,
      Notifications,
      DashboardImportDialog,
      ReportWidget,
      ReportWidgetDialog,
    },
    mixins: [reportsMixin],
    data: () => ({
      baseLayout: [],
      responsiveLayouts: {},
      since: 'last_1h',
      sinceOptions: [
        { text: 'last_1h', value: 1 },
        { text: 'last_3h', value: 3 },
        { text: 'last_6h', value: 6 },
        { text: 'last_12h', value: 12 },
        { text: 'last_24h', value: 24 },
      ],
      managerVisible: false,
      reportWidgetDialog: false,
      managerSettings: null,
      managerWidgets: [],
      managerWidgetKeySequence: 0,
      savedWidgetOrder: [],
      commonWidgetOptions: [
        { label: 'information', type: 'Information' },
        { label: 'resources', type: 'Resources' },
        { label: 'cpu_load', type: 'CPULoad' },
        { label: 'network_information', type: 'NetworkInformation' },
        { label: 'network_layout', type: 'NetworkLayout' },
        { label: 'map_distribution', type: 'MapDistribution' },
        { label: 'policy_overview', type: 'PolicyOverview' },
        { label: 'notifications', type: 'Notifications' },
      ],
      reorderingWidgets: false,
      savingSettings: false,
      layoutReady: false,
    }),
    computed: {
      ...mapGetters('config', {
        dashboardSettings: 'dashboardSettings',
        widgets: 'dashboardWidgets',
      }),
      ...mapGetters('reports', {
        reportCategories: 'categoriesForNav',
      }),
      dashboardLayoutKey() {
        // Remount only when widget identity/order changes. GridLayout mutates coordinates during mount; including x/y
        // here would repeatedly remount it before its resize observer is attached.
        return this.baseLayout.map(widget => widget.id).join('|')
      },
      supportedReportIds() {
        return this.allReports
          .filter(report =>
            ['TIME_GRAPH', 'TIME_GRAPH_DYNAMIC', 'PIE_GRAPH', 'TEXT', 'EVENT_LIST'].includes(report.type),
          )
          .map(report => report.uniqueId)
      },
    },
    watch: {
      /**
       * This is a cached component, so if the widgets change (like on a save), remove this as a cached component so it
       * will be re-mounted.
       */
      widgets() {
        this.$store.commit('DELETE_CACHED_COMPONENT', 'Dashboard')
      },
      managerWidgets: {
        deep: true,
        handler() {
          if (this.managerVisible) {
            this.setLayout()
          }
        },
      },
      allReports() {
        if (this.layoutReady) {
          this.setLayout()
        }
      },
    },
    /** Load dashboard settings, initialize the layout, and cache the route component. */
    async mounted() {
      await this.$store.dispatch('config/getDashboardSettings', true)
      this.setSinceFromSettings()
      this.setLayout()
      this.layoutReady = true
      this.$store.commit('ADD_UNIQUE_CACHED_COMPONENT', 'Dashboard')
    },
    methods: {
      // Open the dashboard settings manager. This will clone the current dashboard settings and prepare the manager widgets for editing.
      openSettings() {
        this.managerSettings = cloneDeep(this.dashboardSettings)
        this.managerWidgets = this.prepareManagerWidgets(this.widgets)
        this.savedWidgetOrder = this.managerWidgets.map(widget => widget._dashboardKey)
        this.reorderingWidgets = false
        this.managerVisible = true
      },

      // Cancel the dashboard settings manager. This will discard any changes made in the manager and reset the layout to the saved dashboard settings.
      cancelSettings() {
        this.managerVisible = false
        this.managerSettings = null
        this.managerWidgets = []
        this.savedWidgetOrder = []
        this.reorderingWidgets = false
        this.setLayout()
      },

      // Toggle the markedForDelete property of a widget in the manager. This is used to mark a widget for deletion without immediately removing it from the managerWidgets array.
      removeWidget(index) {
        const widget = this.managerWidgets[index]
        if (widget) {
          this.$set(widget, 'markedForDelete', !widget.markedForDelete)
        }
      },

      // Check if a widget is supported by the current application. A widget is considered supported if it has a valid component definition and the component is registered in the Vue instance. This is used to determine if a widget can be enabled or displayed in the layout.
      isSupportedWidget(widget) {
        const definition = this.getWidgetDefinition(widget)
        return Boolean(definition && this.$options.components[definition.component])
      },

      // Apply the changes made in the dashboard settings manager. This will save the current manager settings to the store, update the saved widget order, and reset the layout to reflect the new settings. If the save operation fails, an error message will be displayed and the manager will remain open for further editing.
      async applySettings() {
        this.savingSettings = true
        const settings = cloneDeep(this.managerSettings || this.dashboardSettings)
        settings.widgets = this.getWidgetSettings(true)

        try {
          const result = await this.$store.dispatch('config/setDashboardSettings', settings)
          if (!this.isSaveSuccessful(result)) {
            return
          }

          removeDashboardLayout()
          this.managerVisible = false
          this.managerSettings = null
          this.managerWidgets = []
          this.savedWidgetOrder = []
          this.reorderingWidgets = false
          this.setLayout()
        } finally {
          this.savingSettings = false
        }
      },

      // Reset the dashboard settings to their default values. This will prompt the user for confirmation before proceeding. If confirmed, the dashboard settings will be reset, the layout will be cleared, and the manager will be closed. If the reset operation fails, an error message will be displayed and the manager will remain open for further editing.
      resetDashboard() {
        this.$vuntangle.confirm.show({
          title: this.$t('warning'),
          message: this.$t('reset_to_defaults') + '?',
          confirmLabel: this.$t('yes'),
          cancelLabel: this.$t('no'),
          action: async resolve => {
            this.savingSettings = true
            try {
              const result = await this.$store.dispatch('config/resetDashboardSettings')
              if (!this.isSaveSuccessful(result)) {
                return
              }

              removeDashboardLayout()
              this.cancelSettings()
            } finally {
              this.savingSettings = false
              resolve()
            }
          },
        })
      },

      // Enable reordering of widgets in the dashboard settings manager. This will allow the user to drag and drop widgets to change their order. The reordering state is managed by the reorderingWidgets data property, which is set to true when this method is called.
      enableReordering() {
        this.reorderingWidgets = true
      },

      // Generate a unique key for a new widget in the dashboard settings manager. This key is used to identify widgets in the managerWidgets array and ensure that each widget has a distinct identifier. The key is generated by incrementing the managerWidgetKeySequence counter and concatenating it with a prefix string.
      createManagerWidgetKey() {
        this.managerWidgetKeySequence += 1
        return `dashboard-widget-${this.managerWidgetKeySequence}`
      },

      // Prepare the manager widgets for editing by cloning the provided widgets and assigning a unique dashboard key to each widget. This method ensures that the managerWidgets array contains independent copies of the original widgets, allowing for safe modifications without affecting the original settings. The method takes an array of widgets as input and returns a new array of cloned widgets with unique keys.
      prepareManagerWidgets(widgets) {
        return (Array.isArray(widgets) ? widgets : []).map(widget => ({
          ...cloneDeep(widget),
          _dashboardKey: this.createManagerWidgetKey(),
        }))
      },

      isSaveSuccessful(result) {
        if (result?.success) {
          return true
        }

        this.$vuntangle.toast.add(result?.message || this.$t('error_saving_widgets'), 'error')
        return false
      },

      // Add a common widget to the dashboard settings manager. This method creates a new widget object with the specified type and default properties, adds it to the managerWidgets array, and attempts to save the updated settings. If the save operation fails, the newly added widget is removed from the managerWidgets array to maintain consistency. The method is asynchronous and returns a promise that resolves when the operation is complete.
      async addCommonWidget(type) {
        const widget = {
          _dashboardKey: this.createManagerWidgetKey(),
          displayColumns: null,
          enabled: true,
          entryId: null,
          javaClass: 'com.untangle.uvm.DashboardWidgetSettings',
          refreshIntervalSec: null,
          size: 'MEDIUM',
          timeframe: null,
          type,
        }
        this.managerWidgets.push(widget)

        if (!(await this.saveManagerWidgetSettings())) {
          const index = this.managerWidgets.indexOf(widget)
          if (index >= 0) {
            this.managerWidgets.splice(index, 1)
          }
        }
      },

      // Save the settings of a specific widget in the dashboard settings manager. This method attempts to save the current state of the specified widget, including its enabled status and other properties. If the save operation fails, the widget's enabled status is reverted to its previous state to maintain consistency. The method is asynchronous and returns a promise that resolves when the operation is complete.
      async saveWidgetSettings(widget) {
        const enabled = widget.enabled
        if (!(await this.saveManagerWidgetSettings())) {
          widget.enabled = !enabled
        }
      },

      // Save the current state of the dashboard settings manager, including the order and properties of the widgets. This method clones the current manager settings or falls back to the dashboard settings if the manager settings are not available. It then retrieves the saved widget settings and updates the widgets in the settings object. The updated settings are dispatched to the store for persistence. If the save operation is successful, the managerSettings and savedWidgetOrder are updated, and the layout is reset to reflect the new settings. The method returns a boolean indicating whether the save operation was successful.
      async saveManagerWidgetSettings() {
        const settings = cloneDeep(this.managerSettings || this.dashboardSettings)
        const { widgets, order } = this.getSavedWidgetSettings()
        settings.widgets = widgets

        const result = await this.$store.dispatch('config/setDashboardSettings', settings)
        if (!this.isSaveSuccessful(result)) {
          return false
        }

        this.managerSettings = cloneDeep(this.dashboardSettings)
        this.savedWidgetOrder = order
        removeDashboardLayout()
        this.setLayout()
        return true
      },

      // Open the report widget creation dialog. This method sets the reportWidgetDialog data property to true, which triggers the display of the dialog. If there are no reports currently loaded, it dispatches an action to load the reports from the store. The method is asynchronous and returns a promise that resolves when the operation is complete.
      async createReportWidget() {
        this.reportWidgetDialog = true
        if (!this.allReports.length) {
          await this.$store.dispatch('reports/loadReports')
        }
      },

      // Build the report view configuration for a specific report entry. This method takes a report entry as input and uses the buildReportViewConfig utility function to generate the corresponding report view configuration. The method passes the time zone offset, interface name map, and policy name map as additional parameters to ensure that the generated view is accurate and contextually relevant. The resulting configuration can be used to render the report widget in the dashboard.
      buildReportViewForWidget(entry) {
        return buildReportViewConfig(entry, this.timeZoneOffset, this.interfaceNameMap || {}, this.policyNameMap || {})
      },

      // Close the report widget creation dialog. This method sets the reportWidgetDialog data property to false, which hides the dialog from view. It is typically called after a report widget has been successfully added or when the user cancels the creation process. The method does not return any value and is used to manage the visibility state of the dialog within the dashboard component.
      closeReportWidgetDialog() {
        this.reportWidgetDialog = false
      },

      // Add a new report widget to the dashboard settings manager. This method takes an object containing the report entry, enabled status, refresh interval, and display columns as input. It first checks if the report is valid and supported by the application. If valid, it creates a new widget object with the specified properties and adds it to the managerWidgets array. The method then attempts to save the updated settings. If the save operation fails, the newly added widget is removed from the managerWidgets array to maintain consistency. The method is asynchronous and returns a promise that resolves when the operation is complete.
      async addReportWidget({ report, enabled, refreshIntervalSec, displayColumns }) {
        if (!report || !this.supportedReportIds.includes(report.uniqueId)) {
          return
        }

        const widget = {
          _dashboardKey: this.createManagerWidgetKey(),
          displayColumns: displayColumns == null ? null : [...displayColumns],
          enabled,
          entryId: report.uniqueId,
          javaClass: 'com.untangle.uvm.DashboardWidgetSettings',
          refreshIntervalSec,
          size: 'MEDIUM',
          timeframe: null,
          type: 'ReportEntry',
        }

        this.closeReportWidgetDialog()
        this.managerWidgets.push(widget)

        if (!(await this.saveManagerWidgetSettings())) {
          const index = this.managerWidgets.indexOf(widget)
          if (index >= 0) {
            this.managerWidgets.splice(index, 1)
          }
          this.setLayout()
        }
      },

      // Open the import dialog for importing widgets. This method uses the $vuntangle.dialog service to display a dialog with the title "Import Widgets" and the DashboardImportDialog component. The dialog has a width of 600 pixels and an action label for importing. It also listens for the "import" event emitted by the dialog component, which triggers the processImportedWidgets method to handle the imported data. The method does not return any value and is used to initiate the widget import process within the dashboard component.
      openImportDialog() {
        this.$vuntangle.dialog.show({
          title: 'Import Widgets',
          component: DashboardImportDialog,
          width: 600,
          actionLabel: this.$vuntangle.$t('import'),
          componentEvents: { import: data => this.processImportedWidgets(data) },
        })
      },

      // Process the imported widgets data. This method takes the imported data as input and uses the $vuntangle.util.processImportedSettings utility function to validate and process the settings. It compares the imported settings with the current managerWidgets, cleaning them as necessary. If the processing is successful and returns an array of imported widgets, it updates the managerWidgets with the new settings. If an error occurs during processing, it displays an error message using the $vuntangle.toast service. The method is asynchronous and returns a promise that resolves when the operation is complete.
      async processImportedWidgets(data) {
        try {
          const importedWidgets = await this.$vuntangle.util.processImportedSettings(
            this.$vuntangle,
            data,
            this.managerWidgets.map(widget => this.cleanWidgetSettings(widget)),
          )
          if (Array.isArray(importedWidgets)) {
            this.managerWidgets = this.prepareManagerWidgets(importedWidgets)
          }
        } catch (error) {
          this.$vuntangle.toast.add(error?.message || this.$t('import_failed_try_again'), 'error')
        }
      },

      exportWidgets() {
        try {
          this.$vuntangle.util.downloadJsonFile(
            this.getWidgetSettings(),
            this.$vuntangle.util.getExportFilename('Widgets'),
          )
        } catch {
          this.$vuntangle.toast.add(this.$t('export_failed_try_again'), 'error')
        }
      },

      // Set the "since" option based on the current dashboard settings. This method retrieves the timeframe value from the dashboardSettings and finds the corresponding option in the sinceOptions array. If a matching option is found, it updates the since data property with the text of that option. If no matching option is found, it defaults to the first option in the sinceOptions array. The method does not return any value and is used to synchronize the displayed "since" label with the saved dashboard settings.
      setSinceFromSettings() {
        const timeframe = Number(this.dashboardSettings?.timeframe) || 1
        const option = this.sinceOptions.find(item => item.value === timeframe) || this.sinceOptions[0]
        this.since = option.text
      },

      // Update the "since" option and save the new timeframe to the dashboard settings. This method takes an option object containing the text and value of the selected timeframe. It temporarily stores the previous since value, updates the since data property with the new text, and creates a clone of the current dashboardSettings with the updated timeframe. It then dispatches an action to save the updated settings to the store. If the save operation fails, it reverts the since value to its previous state. If the save is successful and the manager is visible, it updates the managerSettings with a clone of the current dashboardSettings. The method is asynchronous and returns a promise that resolves when the operation is complete.
      async updateSince(option) {
        const previousSince = this.since
        this.since = option.text
        const settings = cloneDeep(this.dashboardSettings)
        settings.timeframe = option.value

        const result = await this.$store.dispatch('config/setDashboardSettings', settings)
        if (!this.isSaveSuccessful(result)) {
          this.since = previousSince
        } else if (this.managerVisible) {
          this.managerSettings = cloneDeep(this.dashboardSettings)
        }
      },

      /** Build the dashboard layout from the current settings or temporary manager state. */
      setLayout() {
        const widgetsObject = {}
        const layoutWidgets = this.getLayoutWidgets()
        layoutWidgets.forEach((widget, index) => {
          if (this.isRenderableWidget(widget)) {
            widgetsObject[this.getWidgetId(widget, index, layoutWidgets)] = this.getWidgetDefinition(widget)
          }
        })

        const enabledWidgetIds = new Set(Object.keys(widgetsObject))
        const storedLayout = this.$vuntangle.widgets.getStoredLayout('dashboard-layout')
        const storedWidgets = storedLayout ? Object.values(storedLayout).flat() : []
        const storedWidgetIds = new Set(storedWidgets.map(widget => widget.id))
        const breakpoint = this.$vuntangle.widgets.getBreakpoint()
        const storedWidgetOrder = storedLayout?.[breakpoint]?.map(widget => widget.id) || []
        const widgetOrderIsCurrent =
          storedWidgetOrder.length === enabledWidgetIds.size &&
          [...enabledWidgetIds].every((widgetId, index) => storedWidgetOrder[index] === widgetId)
        const storedLayoutIsCurrent =
          storedWidgets.length > 0 &&
          Array.isArray(storedLayout?.[breakpoint]) &&
          storedLayout[breakpoint].length > 0 &&
          widgetOrderIsCurrent &&
          storedWidgetIds.size === enabledWidgetIds.size &&
          [...enabledWidgetIds].every(widgetId => storedWidgetIds.has(widgetId)) &&
          storedWidgets.every(widget => {
            const definition = widgetsObject[widget.id]
            return (
              enabledWidgetIds.has(widget.id) &&
              definition?.component === widget.cmp &&
              widget.w === (definition?.width || 1)
            )
          })

        // While editing settings, render the temporary manager order directly. Do not use or overwrite the stored
        // layout until the user applies the changes.
        if (!this.managerVisible && storedLayoutIsCurrent) {
          this.responsiveLayouts = storedLayout
          this.baseLayout = cloneDeep(this.responsiveLayouts[breakpoint])

          return
        }

        if (!this.managerVisible && storedLayout) {
          removeDashboardLayout()
        }

        this.responsiveLayouts = this.$vuntangle.widgets.getLayout(Object.keys(widgetsObject), widgetsObject)
        Object.keys(this.responsiveLayouts).forEach(bp => {
          this.responsiveLayouts[bp].forEach(widget => {
            const def = widgetsObject[widget.id]
            if (def?.height) widget.h = def.height
          })
        })
        this.baseLayout = cloneDeep(this.responsiveLayouts[this.$vuntangle.widgets.getBreakpoint()])

        // Store the grid only after the settings are committed. Temporary reorder changes must not survive a refresh.
        if (!this.managerVisible) {
          this.storeLayout()
        }
      },

      // Check if a widget is renderable. A widget is renderable if it is enabled and has a valid component definition. This is used to filter out widgets that should not be displayed in the layout.
      isRenderableWidget(widget) {
        const definition = this.getWidgetDefinition(widget)
        return Boolean(widget.enabled !== false && definition && this.$options.components[definition.component])
      },

      // Get the widgets to use for the current layout. If the manager is visible, use the temporary manager state. Otherwise, use the saved dashboard settings.
      getLayoutWidgets() {
        return this.managerVisible ? this.managerWidgets : this.widgets
      },

      // Get the widget settings for the current manager state. This is used when saving the dashboard settings to ensure that the widgets are saved in the correct order and with the correct properties. If removeMarked is true, any widgets marked for deletion will be excluded from the returned array.
      getWidgetSettings(removeMarked = false) {
        return this.managerWidgets
          .filter(widget => !removeMarked || !widget.markedForDelete)
          .map(widget => this.cleanWidgetSettings(widget))
      },

      // Get the saved widget settings and order for the current manager state. This is used when saving the dashboard settings to ensure that the widgets are saved in the correct order and with the correct properties.
      getSavedWidgetSettings() {
        const widgetsByKey = new Map(
          this.managerWidgets.map(widget => [widget._dashboardKey, this.cleanWidgetSettings(widget)]),
        )
        const currentOrder = this.managerWidgets.map(widget => widget._dashboardKey)
        const order = [
          ...this.savedWidgetOrder,
          ...currentOrder.filter(key => !this.savedWidgetOrder.includes(key)),
        ].filter(key => widgetsByKey.has(key))

        return {
          widgets: order.map(key => widgetsByKey.get(key)),
          order,
        }
      },

      // Clean a widget object by removing internal properties that should not be saved. This is used when saving the dashboard settings to ensure that only the relevant properties are stored.
      cleanWidgetSettings(widget) {
        const settings = cloneDeep(widget)
        delete settings._id
        delete settings._dashboardKey
        delete settings.markedForDelete
        return settings
      },

      // Get a unique ID for a widget. This is used to identify the widget in the layout. For report widgets, this will include the entry ID and an occurrence count to ensure uniqueness. For other widgets, it will just be the widget type.
      getWidgetId(widget, index, widgets = this.getLayoutWidgets()) {
        const widgetIndex = index ?? widgets.indexOf(widget)
        const baseId = this.getWidgetBaseId(widget)
        const occurrence = widgets
          .slice(0, widgetIndex + 1)
          .filter(item => this.getWidgetBaseId(item) === baseId).length
        return occurrence > 1 ? `${baseId}:${occurrence}` : baseId
      },

      // Get the base ID for a widget. For report widgets, this will include the entry ID to ensure uniqueness. For other widgets, it will just be the widget type.
      getWidgetBaseId(widget) {
        return widget.type === 'ReportEntry' ? `${widget.type}:${widget.entryId}` : widget.type
      },

      // Get the widget object for a given layout widget. This is used to get the title and other information for the widget.
      getLayoutWidgetWidget(layoutWidget) {
        const widgets = this.getLayoutWidgets()
        return widgets.find((item, index) => this.getWidgetId(item, index, widgets) === layoutWidget.id) || layoutWidget
      },

      // Get the title for a given widget. For report widgets, this will return the report title. For other widgets, it will return the label from the common widget options or the widget type if no label is found.
      widgetTitle(widget) {
        if (widget.type === 'ReportEntry') {
          return this.getReport(widget)?.title || widget.entryId || widget.type
        }
        const definition = widgetComponents[widget.type]
        if (definition?.title) return this.$t(definition.title)
        const label = this.commonWidgetOptions.find(option => option.type === widget.type)?.label
        return label ? this.$t(label) : widget.type
      },

      // Get the report object for a given widget. This is used to get the title and other information for report widgets.
      getReport(widget) {
        return this.allReports.find(report => report.uniqueId === widget.entryId)
      },

      // Get the widget definition for a given widget.
      getWidgetDefinition(widget) {
        if (widget.type !== 'ReportEntry') {
          return widgetComponents[widget.type]
        }

        const report = this.getReport(widget)
        if (!report) {
          return null
        }

        const refreshInterval = Number(widget.refreshIntervalSec)
        return {
          component: 'ReportWidget',
          interval: Number.isFinite(refreshInterval) && refreshInterval > 0 ? refreshInterval : 60,
          title: report.title || widget.entryId,
          width: 1,
        }
      },

      // Get the widget definition for a given layout widget.
      getLayoutWidgetDefinition(layoutWidget) {
        const widgets = this.getLayoutWidgets()
        const widget = widgets.find((item, index) => this.getWidgetId(item, index, widgets) === layoutWidget.id)
        return widget ? this.getWidgetDefinition(widget) : widgetComponents[layoutWidget.id] || null
      },

      // Get the props to pass to the component for a given layout widget. This includes the refresh interval, title, report data, and display columns for report widgets.
      getLayoutWidgetProps(layoutWidget) {
        const definition = this.getLayoutWidgetDefinition(layoutWidget)
        if (!definition) {
          return {}
        }

        const props = { interval: definition.interval }
        if (definition.component === 'ReportWidget') {
          const widgets = this.getLayoutWidgets()
          const widget = widgets.find((item, index) => this.getWidgetId(item, index, widgets) === layoutWidget.id)
          props.title = definition.title
          props.report = widget ? this.getReport(widget) : null
          props.displayColumns = widget?.displayColumns ?? null
          props.timeframe = Number(this.dashboardSettings?.timeframe) || 1
        }
        return props
      },

      // Store the current layout in local storage for the current breakpoint. This allows the layout to persist across page reloads and browser sessions.
      storeLayout() {
        const storedLayout = cloneDeep(this.responsiveLayouts)
        storedLayout[this.$vuntangle.widgets.getBreakpoint()] = this.baseLayout

        this.$vuntangle.widgets.setStoredLayout('dashboard-layout', storedLayout)
      },
    },
  }
</script>
<style scoped>
  .dashboard-page {
    height: 100%;
  }

  .dashboard-layout {
    display: flex;
    height: 100%;
  }

  .dashboard-content {
    min-width: 0;
    flex: 1;
  }

  .dashboard-manager {
    display: flex;
    width: 340px;
    min-width: 340px;
    flex-direction: column;
    border-right: 1px solid #d8d8d8;
  }

  .dashboard-manager__toolbar {
    display: flex;
    align-items: center;
    height: 30px;
    min-height: 30px;
    margin-bottom: 8px;
    padding: 0 8px;
    position: relative;
  }

  .dashboard-manager__toolbar::after {
    position: absolute;
    right: 0;
    bottom: -12px;
    left: 0;
    border-bottom: 1px solid #d8d8d8;
    content: '';
  }

  .dashboard-manager__widgets-button {
    width: 160px;
  }

  .dashboard-manager__list {
    flex: 0 1 auto;
    max-height: calc(100% - 94px);
    overflow-y: auto;
  }

  .dashboard-manager__list ::v-deep .v-list-item {
    padding-left: 4px;
  }

  .dashboard-manager__order-cell {
    flex: 0 0 20px;
    width: 20px;
    min-width: 30px;
    max-width: 10px;
    margin: 0 !important;
    padding: 0 !important;
    justify-content: center;
  }

  .dashboard-manager__drag-handle {
    cursor: grab;
  }

  .dashboard-manager__actions {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    padding: 8px;
  }

  .dashboard-toolbar {
    display: flex;
    align-items: center;
    gap: 8px;
    height: 30px;
    padding: 0 8px;
  }

  .dashboard-toolbar__button {
    flex: 0 0 auto;
    font-size: 12px;
  }

  .dashboard-toolbar__settings {
    width: 120px;
  }

  .dashboard-toolbar__conditions {
    flex: 0 0 auto;
    width: auto;
  }

  .dashboard-toolbar__conditions ::v-deep .v-btn {
    width: auto;
  }

  .dashboard-toolbar__since {
    width: 160px;
  }

  .dashboard-toolbar__button .v-icon {
    font-size: 14px;
  }
</style>
