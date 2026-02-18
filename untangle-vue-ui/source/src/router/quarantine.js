import QuarantineLayout from '@/layouts/QuarantineLayout.vue'
import QuarantineDigestRequest from '@/components/settings/system/QuarantineDigestRequest.vue'
import QuarantineDigestInbox from '@/components/settings/system/QuarantineDigestInbox.vue'

export default [
  {
    name: 'quarantine',
    path: '/email-quarantine-digest',
    component: QuarantineDigestRequest,
    meta: {
      layout: QuarantineLayout,
      helpContext: 'quarantine',
    },
  },
  {
    name: 'quarantine-manageuser',
    path: '/email-quarantine-digest/manageuser',
    component: QuarantineDigestInbox,
    meta: {
      layout: QuarantineLayout,
      helpContext: 'quarantine',
    },
  },
]
