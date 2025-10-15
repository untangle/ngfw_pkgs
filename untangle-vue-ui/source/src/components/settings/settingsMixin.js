import cloneDeep from 'lodash/cloneDeep'
import isEqual from 'lodash/isEqual'
import util from '@/util/util'

let reloaded = false

export default {
  props: {
    settings: { type: [Object, Array], default: null },
    disabled: { type: Boolean, default: false },
    // matches styles to ETM, uses h1 for page titles and makes the component expand the whole width
    classicView: { type: Boolean, required: false, default: false },
    // used to show / hide the description field; shown for mfw-ui but hidden in ETM
    showDescription: { type: Boolean, default: false },
    // keeping isChanged separate from isDirty until we make CD-5042 change for all appliance components
    isChanged: { type: Boolean, default: false },
  },

  data() {
    return {
      settingsCopy: undefined,
      invalidSettingsErrors: undefined,
    }
  },
  computed: {
    isDirty: ({ settings, settingsCopy, $options }) => !isEqual(settings || $options.defaults, settingsCopy),
  },
  watch: {
    /**
     * settings watcher firing only once and only when incoming settings are undefined
     * in such case it will fallback to dedicated defaults defined for each service (if any)
     */
    settings: {
      immediate: true,
      handler(settings) {
        // must clone settings and default settings or default will be changed when going to other services
        this.settingsCopy = settings
          ? cloneDeep(settings)
          : this.$options.defaults
          ? cloneDeep(this.$options.defaults)
          : null
      },
    },
    isDirty: {
      immediate: true,
      handler(value) {
        this.$emit('update:isChanged', value)
      },
    },
  },

  methods: {
    // reverts all changes in the list to the original ones
    onUndo() {
      this.settingsCopy = cloneDeep(this.settings)
    },

    /**
     * Exports the rules to a JSON file.
     * @param {Array} existingSettings The settings to be exported.
     */
    onExportSettings(existingSettings) {
      if (!existingSettings) return
      const settings = existingSettings
      if (this.exportOmitProperties) {
        settings.forEach(setting => {
          this.exportOmitProperties.forEach(prop => {
            delete setting[prop]
          })
        })
      }
      this.exportGridSettings(this.gridName, settings)
    },

    /**
     * Imports rules from a JSON file.
     * @param {Object} data The import data, including importMode and file.
     * @param {Array} existingSettings The existing settings.
     * @returns {Promise<Array>} The updated settings array.
     */
    async onImportSettings(data, existingSettings) {
      const importedData = await this.importGridSettings(data.importMode, data.file)
      if (importedData?.success) {
        return this.processImportedGridSettings(
          existingSettings || [],
          importedData.msg,
          data.importMode,
          this.idProperty,
        )
      }
      return existingSettings
    },

    /**
     * Calls gridSettings handler and exports grid settings to a json file
     * @param {String} gridName
     * @param {Array} gridData
     */
    async exportGridSettings(gridName, gridData) {
      this.$store.commit('SET_LOADER', true)
      try {
        await util.downloadFile('/admin/gridSettings', {
          type: 'export',
          gridName,
          gridData: JSON.stringify(gridData),
        })
      } catch (error) {
        this.$vuntangle.toast.add(this.$vuntangle.$t('export_failed_try_again'), 'error')
      } finally {
        this.$store.commit('SET_LOADER', false)
      }
    },

    /**
     * Uploads a file to the server for import.
     * @param {String} importMode
     * @param {File} file
     */
    async importGridSettings(importMode, file) {
      this.$store.commit('SET_LOADER', true)
      try {
        return await util.uploadFile('/admin/gridSettings', {
          type: 'import',
          importMode,
          file,
        })
      } catch (error) {
        this.$vuntangle.toast.add(this.$vuntangle.$t('import_failed_try_again'), 'error')
      } finally {
        this.$store.commit('SET_LOADER', false)
      }
    },

    /**
     * Processes imported grid settings based on the import mode.
     * @param {Array} existingSettings The existing settings.
     * @param {Array} importedSettings The settings that were imported.
     * @param {String} importMode The import mode ('replace', 'prepend', or 'append').
     * @param {String} idProperty The name of the unique identifier property.
     * @returns {Array} The processed settings array.
     */
    processImportedGridSettings(existingSettings, importedSettings, importMode, idProperty) {
      // If the existing settings have an ID property, add a new UUID to the imported settings.
      if (idProperty && existingSettings?.some(setting => setting[idProperty])) {
        importedSettings.forEach(setting => {
          setting[idProperty] = util.uuidv4()
        })
      }

      if (importMode === 'replace') {
        return importedSettings
      } else if (importMode === 'prepend') {
        return [...importedSettings, ...existingSettings]
      } else if (importMode === 'append') {
        return [...existingSettings, ...importedSettings]
      }
      return existingSettings
    },
  },

  /**
   * Lifecycle hook to detect browser reload.
   * If a reload is detected, calls the `onBrowserRefresh` method.
   */
  created() {
    if (!reloaded) {
      reloaded = true
      this.onBrowserRefresh?.()
    }
  },
}
