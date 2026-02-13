/**
 * Apps Module Routes
 *
 * This module handles routing for the Apps management interface,
 * supporting policy-based app management with dynamic app loading.
 *
 * Route Structure:
 * - /apps/:policyId - Main apps view for a specific policy
 * - /apps/:policyId/:appName - Individual app settings view
 */

import AppsLayout from '@/components/Apps/AppsLayout.vue'
import AppSettingsLayout from '@/components/Apps/AppSettingsLayout.vue'
import AppsView from '@/components/Apps/AppsView.vue'

export default [
  {
    // Root path for all apps-related routes
    path: '/apps',
    component: AppsLayout,
    meta: {
      // Add metadata for route guards or analytics if needed
      requiresAuth: true,
      module: 'apps',
    },
    children: [
      {
        // Main apps view - displays installed and installable apps for a policy
        // Example: /apps/1 (shows apps for policy ID 1)
        path: ':policyId',
        name: 'apps',
        component: AppsView,
        meta: {
          title: 'Apps',
          description: 'Manage installed and installable apps',
        },
        props: route => ({
          // Convert policyId to number for component prop
          policyId: Number(route.params.policyId),
        }),
      },
      {
        // Individual app settings view - dynamically loads app-specific components
        // Example: /apps/1/web-filter (loads WebFilter component for policy 1)
        path: ':policyId/:appName',
        name: 'app-settings',
        component: AppSettingsLayout,
        meta: {
          title: 'App Settings',
          description: 'Configure app-specific settings',
        },
        props: route => ({
          // Convert policyId to number and pass appName as string
          policyId: Number(route.params.policyId),
          appName: route.params.appName,
        }),
      },
    ],
  },
]
