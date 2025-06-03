// import cloneDeep from 'lodash/cloneDeep'
// import api from '@/plugins/api'

// import { DeleteInterfaceDialog } from '@/components/settings/interface'

// export default {
//   methods: {
//     /**
//      * Removes the interface
//      * - shows a confirm dialog
//      *
//      * @param {*} intf the interface to delete
//      * @param {*} successCallback callback to be executed in case of success
//      */
//     async deleteInterfaceHandler(intf, successCallback = () => {}) {
//       const hasWanPolicy = this.$store.getters['settings/hasWanPolicy'](intf.interfaceId)
//       const showDialog = intf.wan === false || (intf.wan === true && !hasWanPolicy)
//       const interfacesCopy = cloneDeep(this.$store.getters['settings/interfaces'])
//       const affectedChildInterfaces = this.showDeleteWarning(intf, interfacesCopy)
//       if (affectedChildInterfaces.length) {
//         this.$vuntangle.dialog.show({
//           title: `${this.$t('cannot_delete_interface')}`,
//           component: DeleteInterfaceDialog,
//           width: 800,
//           buttons: [],
//           componentProps: {
//             intf,
//             affectedChildInterfaces,
//           },
//           componentEvents: {
//             update: successCallback,
//           },
//         })
//       } else if ((intf.type === 'VLAN' && showDialog) || intf.type === 'BRIDGE') {
//         this.$vuntangle.dialog.show({
//           title: `${this.$t('delete_interface')}`,
//           component: DeleteInterfaceDialog,
//           width: 800,
//           actionLabel: this.$t('yes'),
//           cancelLabel: this.$t('no'),
//           componentProps: {
//             intf,
//           },
//           componentEvents: {
//             update: successCallback,
//           },
//         })
//       } else {
//         const index = interfacesCopy.findIndex(({ interfaceId }) => interfaceId === intf.interfaceId)

//         interfacesCopy.splice(index, 1)

//         this.$store.commit('SET_LOADER', true)
//         await api.post('/api/settings/network/interfaces', interfacesCopy)
//         successCallback()
//         await this.$store.dispatch('settings/getSettings', true)

//         this.$store.commit('SET_LOADER', false)
//       }
//     },

//     /**
//      * show a warning if the interface to be deleted is bound to other interfaces
//      *
//      * @param intf the interface to be deleted
//      * @param {*} interfaces list of all inerfaces
//      * @returns
//      */
//     showDeleteWarning(intf, interfaces) {
//       if (!interfaces || intf.type !== 'BRIDGE') {
//         return []
//       }
//       // add to the following array the interfaceIds of all the interfaces whose parent is intf.
//       const affectedChildInterfaces = []
//       interfaces.forEach(i => {
//         if (
//           i.boundInterfaceId &&
//           i.boundInterfaceId === intf.interfaceId &&
//           !affectedChildInterfaces.includes(i.name)
//         ) {
//           affectedChildInterfaces.push(i.name)
//         }
//       })
//       return affectedChildInterfaces
//     },
//   },
// }
