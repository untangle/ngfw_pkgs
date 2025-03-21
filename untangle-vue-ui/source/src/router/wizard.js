import BlankLayout from '@/layouts/BlankLayout.vue'
import wizard from '@/components/setup/Wizard.vue'

export default [
  {
    path: '/setup',
    name: 'wizard',
    component: wizard,
    meta: { layout: BlankLayout },
  },
]
