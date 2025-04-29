import cloneDeep from 'lodash/cloneDeep'
import isEqual from 'lodash/isEqual'

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

  created() {
    console.log('settings inside mixin :', this.settings)
    console.log('settingsCopy inside mixin :', this.settingsCopy)
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
  },
}
