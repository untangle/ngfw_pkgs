import Vue from 'vue'
import VUntangle, {
  AgGridVue,
  UGrid,
  UChart,
  UChartOverlay,
  UChartStock,
  UBtn,
  UCheckbox,
  UTextField,
  USection,
  USelect,
  UErrorsTooltip,
  UFrameworkDialog,
  UFrameworkConfirm,
  UFrameworkToast,
  UAlert,
  UWidget,
  UNetworkLayout,
  USheet,
  UPassword,
  Ipv4PrefixAutocomplete,
} from 'vuntangle'

// determine which environment the host application is running in, used for sentry logging
const host = window.location.host
const env = process.env.NODE_ENV === 'development' ? 'devServer' : host.includes('ngfw') ? 'local' : 'production'

// install the plugin
Vue.use(VUntangle, {
  env,
  components: {
    AgGridVue,
    UGrid,
    UChart,
    UChartOverlay,
    UChartStock,
    UBtn,
    UCheckbox,
    UTextField,
    USection,
    USelect,
    UErrorsTooltip,
    UFrameworkDialog,
    UFrameworkConfirm,
    UFrameworkToast,
    UAlert,
    UWidget,
    UNetworkLayout,
    USheet,
    UPassword,
    Ipv4PrefixAutocomplete,
  },
})

// create plugin instance
export default new VUntangle()
