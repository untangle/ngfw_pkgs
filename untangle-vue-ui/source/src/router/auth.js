import DynamicLayout from '@/layouts/DynamicLayout'
import Login from '@/components/auth/Login'

export default [
  {
    path: '/login',
    name: 'login',
    component: Login,
    meta: { layout: DynamicLayout },
  },
]
