import cloneDeep from 'lodash/cloneDeep'

import { DeleteInterfaceDialog } from '@/components/settings/interface'

export default {
  methods: {
    /**
     * Removes the interface
     * - shows a confirm dialog
     *
     * @param {*} intf the interface to delete
     * @param {*} successCallback callback to be executed in case of success
     */
    deleteInterfaceHandler(intf, successCallback = () => {}) {
      // We don't allow deletion of NIC or WIFI interfaces from the UI
      // Still added this check to prevent accidental deletion
      if (intf.type === 'NIC' || intf.type === 'WIFI') return

      const interfacesCopy = cloneDeep(this.$store.getters['settings/interfaces'])
      const affectedInterfaces = this.getAffectedBridgedInterfaces(intf, interfacesCopy)
      if (affectedInterfaces.length) {
        this.$vuntangle.dialog.show({
          title: `${this.$t('cannot_delete_interface')}`,
          component: DeleteInterfaceDialog,
          width: 800,
          buttons: [],
          componentProps: {
            intf,
            affectedInterfaces,
          },
          componentEvents: {
            update: successCallback,
          },
        })
      } else if (intf.type === 'VLAN') {
        this.$vuntangle.dialog.show({
          title: `${this.$t('delete_interface')}`,
          component: DeleteInterfaceDialog,
          width: 800,
          actionLabel: this.$t('yes'),
          cancelLabel: this.$t('no'),
          componentProps: {
            intf,
          },
          componentEvents: {
            update: successCallback,
          },
        })
      }
    },

    /**
     * Returns the list of interfaces that are affected by the deletion of the given interface.
     * @param intf the interface to be deleted
     * @param {*} interfaces list of all inerfaces
     * @returns
     */
    getAffectedBridgedInterfaces(intf, interfaces) {
      if (!interfaces) return []
      return [...new Set(interfaces.filter(i => i.bridgedTo === intf.interfaceId).map(i => i.name))]
    },
  },
}
