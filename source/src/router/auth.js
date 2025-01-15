// import BlankLayout from '@@/layouts/index'
import BlankLayout from '@/layouts/BlankLayout'
// import Login from '@/components/index'
import Login from '@/components/auth/Login'

export default [
  {
    path: '/login',
    name: 'login',
    component: Login,
    meta: { layout: BlankLayout },
  },
]
