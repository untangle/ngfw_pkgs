import BlankLayout from '@/layouts/BlankLayout.vue'
import wizard from '@/components/setup/Wizard.vue'

export default [
  {
    path: '/',
    name: 'wizard',
    component: wizard,
    meta: { layout: BlankLayout },
  },
]
