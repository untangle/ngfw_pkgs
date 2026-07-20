import QuarantineLayout from '@/layouts/QuarantineLayout.vue'
import QuarantineDigestRequest from '@/components/settings/system/QuarantineDigestRequest.vue'
import QuarantineDigestInbox from '@/components/settings/system/QuarantineDigestInbox.vue'

export default [
  {
    name: 'quarantine',
    path: '/quarantine',
    component: QuarantineDigestRequest,
    meta: {
      layout: QuarantineLayout,
      helpContext: 'quarantine',
    },
  },
  {
    name: 'quarantine-manageuser',
    path: '/quarantine/manageuser',
    component: QuarantineDigestInbox,
    meta: {
      layout: QuarantineLayout,
      helpContext: 'quarantine',
    },
  },
]
