import UserApiLayout from '@/layouts/UserApiLayout.vue'
import NotificationUserapiPage from '@/components/settings/services/NotificationUserapiPage.vue'

export default [
  {
    name: 'userapi',
    path: '/userapi',
    component: NotificationUserapiPage,
    meta: {
      layout: UserApiLayout,
      helpContext: 'userapi',
    },
  },
]
