import cloneDeep from 'lodash/cloneDeep'
import isEqual from 'lodash/isEqual'

export default {
  props: {
    settings: { type: [Object, Array], default: null },
    disabled: { type: Boolean, default: false },
    classicView: { type: Boolean, required: false, default: false },
    showDescription: { type: Boolean, default: false },
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
        // TODO show similar popup on Vue screen
        window.parent.postMessage(
          {
            source: 'vue-iframe-app', // A unique identifier
            type: 'isDirtyChange',
            isDirty: value,
          },
          '*',
        ) // '*' means allow communication with any origin.
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
