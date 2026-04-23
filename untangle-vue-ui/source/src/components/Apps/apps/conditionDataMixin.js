/**
 * Factory mixin for app components that need runtime condition dropdown data.
 *
 * @param {string[]} appNames - Service names whose condition data to fetch (e.g. ['directory-connector'])
 *
 * Usage:
 *   import conditionDataMixin from '../conditionDataMixin'
 *   mixins: [appMixin, conditionDataMixin(['directory-connector'])]
 *
 *   Then include the needed keys in provide() → $remoteData:
 *   $remoteData: () => ({ ..., directoryGroups: this.directoryGroups, directoryDomains: this.directoryDomains })
 */
export default function conditionDataMixin(appNames = []) {
  return {
    computed: {
      conditionData: ({ $store }) => $store.getters['apps/conditionData'],
      directoryGroups: ({ conditionData }) =>
        conditionData?.directoryGroups?.length
          ? [{ text: 'Any Group', value: '*' }, ...conditionData.directoryGroups]
          : [],
      directoryDomains: ({ conditionData }) =>
        conditionData?.directoryDomains?.length
          ? [{ text: 'Any Domain', value: '*' }, ...conditionData.directoryDomains]
          : [],
    },
    created() {
      this.$store.dispatch('apps/fetchConditionData', appNames)
    },
  }
}
