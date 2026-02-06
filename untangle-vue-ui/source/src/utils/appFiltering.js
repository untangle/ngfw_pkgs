/**
 * App Filtering Utilities
 *
 * This module provides utility functions for filtering, organizing, and managing
 * apps within the policy-based app management system.
 *
 * Key Features:
 * - Build policy hierarchies from flat lists
 * - Filter installed apps with parent policy inheritance
 * - Filter installable apps (FILTER type only)
 * - Calculate power state indicators
 * - Sort apps by view position and policy hierarchy
 */

import util from '@/util/util'
import { appDescription } from '@/constants/index'

// ============================================
// Constants
// ============================================

/**
 * App run states from backend
 * @readonly
 * @enum {string}
 */
const RUN_STATE = {
  RUNNING: 'RUNNING',
  STOPPED: 'STOPPED',
}

/**
 * Power state CSS classes for UI
 * @readonly
 * @enum {string}
 */
const POWER_CLASS = {
  ON: 'on',
  OFF: '',
  INCONSISTENT: 'inconsistent',
}

/**
 * App types from backend
 * Only FILTER apps are shown in installable apps view
 * SERVICE apps are excluded from installation UI
 * @readonly
 * @enum {string}
 */
const APP_TYPE = {
  FILTER: 'FILTER',
  SERVICE: 'SERVICE',
}

/**
 * Installation status values
 * @readonly
 * @enum {string}
 */
const INSTALL_STATUS = {
  PROGRESS: 'progress',
  FINISH: 'finish',
}

/**
 * Default view position for apps without explicit position
 * Used for sorting - ensures unprioritized apps appear last
 * @constant {number}
 */
const DEFAULT_VIEW_POSITION = 999

// ============================================
// Policy Hierarchy Functions
// ============================================

/**
 * Builds a hierarchical policy tree from a flat policy list
 *
 * Converts a flat array of policies with parent-child relationships
 * into a nested tree structure suitable for tree view components.
 *
 * @param {Array<Object>} policies - Flat list of policy objects
 * @param {number} policies[].policyId - Unique policy identifier
 * @param {number} [policies[].parentId] - Parent policy ID (null for root policies)
 * @returns {Array<Object>} Hierarchical policy tree with children arrays
 *
 * @example
 * const policies = [
 *   { policyId: 1, name: 'Root', parentId: null },
 *   { policyId: 2, name: 'Child', parentId: 1 }
 * ]
 * const tree = buildPolicyHierarchy(policies)
 * // Returns: [{ policyId: 1, name: 'Root', parentId: null, children: [{ policyId: 2, ... }] }]
 */
export function buildPolicyHierarchy(policies) {
  // Guard clause for invalid input
  if (!policies || !Array.isArray(policies)) {
    return []
  }

  // Create a map for O(1) policy lookup
  const policyMap = {}
  policies.forEach(policy => {
    policyMap[policy.policyId] = { ...policy, children: [] }
  })

  // Build tree by connecting parents and children
  const tree = []
  policies.forEach(policy => {
    if (!policy.parentId) {
      // Root policy - no parent
      tree.push(policyMap[policy.policyId])
    } else if (policyMap[policy.parentId]) {
      // Child policy - add to parent's children array
      policyMap[policy.parentId].children.push(policyMap[policy.policyId])
    }
  })

  return tree
}

/**
 * Builds the policy hierarchy chain from a policy up to the root
 *
 * Traverses from the selected policy up through parent policies to build
 * a complete chain for inheritance calculations.
 *
 * @param {Object} selectedPolicy - Starting policy object
 * @param {Object<number, Object>} policyMap - Map of policyId to policy object
 * @returns {Array<number>} Array of policy IDs from selected to root
 *
 * @example
 * // If policy 3 has parent 2, which has parent 1 (root)
 * buildPolicyChain(policy3, policyMap) // Returns: [3, 2, 1]
 */
function buildPolicyChain(selectedPolicy, policyMap) {
  const policyHierarchy = [selectedPolicy.policyId]
  let currentPolicy = selectedPolicy

  // Traverse up the hierarchy until we reach a root policy
  while (currentPolicy && currentPolicy.parentId) {
    currentPolicy = policyMap[currentPolicy.parentId]
    if (currentPolicy) {
      policyHierarchy.push(currentPolicy.policyId)
    }
  }

  return policyHierarchy
}

// ============================================
// Power State Functions
// ============================================

/**
 * Determines the power state CSS class for an app instance
 *
 * Calculates the power state by comparing run state, target state, and daemon status.
 * Returns appropriate CSS class for visual indicator.
 *
 * States:
 * - 'inconsistent': App is transitioning or daemon has issues
 * - 'on': App is running normally
 * - '': App is stopped (empty string for 'off' state)
 *
 * @param {Object} app - App instance object
 * @param {string} app.targetState - Desired state (RUNNING/STOPPED)
 * @param {string} runState - Current run state (RUNNING/STOPPED)
 * @param {string} [daemon] - Daemon name to check if running (optional)
 * @returns {string} Power state CSS class
 */
export function getPowerClass(app, runState, daemon) {
  // Determine if app should be running
  const isRunning = runState === RUN_STATE.RUNNING
  const targetState = app.targetState

  // Check daemon status if daemon name is provided and app is running
  const daemonRunning =
    isRunning && daemon != null ? window.rpc.directData('rpc.UvmContext.daemonManager.isRunning', daemon) : true

  // App is inconsistent if:
  // 1. Target state doesn't match current state (transitioning)
  // 2. App is running but daemon is not running
  const isInconsistent = targetState !== runState || (runState === RUN_STATE.RUNNING && !daemonRunning)

  if (isInconsistent) {
    return POWER_CLASS.INCONSISTENT
  } else if (isRunning) {
    return POWER_CLASS.ON
  } else {
    return POWER_CLASS.OFF
  }
}

// ============================================
// App Enrichment Functions
// ============================================

/**
 * Enriches an app instance with UI metadata
 *
 * Adds display properties, license information, power state, and installation status
 * to the raw app instance from the backend.
 *
 * @param {Object} app - Raw app instance
 * @param {Object} view - App view containing properties and states
 * @param {Object} appProperties - App metadata (displayName, daemon, etc.)
 * @param {string} [parentPolicyName] - Name of parent policy if inherited
 * @param {Object} installingApps - Map of apps currently being installed
 * @param {Object} $vuntangle - Vue i18n instance
 * @returns {Object} Enriched app object with UI properties
 */
function enrichAppInstance(app, view, appProperties, parentPolicyName, installingApps, $vuntangle) {
  const enrichedApp = { ...app }

  // Mark if inherited from parent policy
  if (parentPolicyName) {
    enrichedApp.parentPolicy = parentPolicyName
  }

  // Add app metadata
  enrichedApp.hasPowerButton = appProperties ? appProperties.hasPowerButton : false
  enrichedApp.displayName = appProperties ? appProperties.displayName : app.appName
  enrichedApp.viewPosition = appProperties ? appProperties.viewPosition : DEFAULT_VIEW_POSITION

  // Add license information
  const license = view.licenseMap[app.appName]
  enrichedApp.licenseMessage = util.getLicenseMessage(license, $vuntangle)

  // Calculate power state
  enrichedApp.powerCls = getPowerClass(enrichedApp, view.runStates[enrichedApp.id], appProperties?.daemon)

  // Check if currently being installed
  const installing = installingApps[app.appName]
  enrichedApp.installing = installing ? installing.status === INSTALL_STATUS.PROGRESS : false

  // Store all properties for reference
  enrichedApp.props = appProperties || {}

  return enrichedApp
}

// ============================================
// App Filtering Functions
// ============================================

/**
 * Gets installed apps for a policy including apps inherited from parent policies
 *
 * Retrieves all apps for the selected policy and traverses up the policy hierarchy
 * to include apps from parent policies. Inherited apps are marked with parent policy name.
 *
 * Installation State Handling:
 * This function merges two sources of state to handle the race condition during app installation:
 * 1. Backend instances (from view.instances) - Apps created by backend
 * 2. UI state (from installingApps) - Apps in 'progress' status
 *
 * When user installs an app and navigates back quickly, the backend may not have created
 * the instance yet. By checking installingApps and creating placeholder objects, we ensure
 * installing apps always appear with loader, regardless of backend timing.
 *
 * @param {Object} params - Function parameters
 * @param {Object<number, Object>} params.appViewsByPolicy - Normalized app views keyed by policyId
 * @param {Object} params.selectedPolicy - Currently selected policy object
 * @param {Array<Object>} params.policies - Complete list of all policies
 * @param {Object} params.$vuntangle - Vue i18n instance for translations
 * @param {Object} [params.installingApps={}] - Map of apps currently being installed
 * @returns {Array<Object>} Sorted array of enriched app objects
 *
 * @example
 * const apps = getInstalledApps({
 *   appViewsByPolicy: { 1: {...}, 2: {...} },
 *   selectedPolicy: { policyId: 2, parentId: 1 },
 *   policies: [...],
 *   $vuntangle,
 *   installingApps: {}
 * })
 */
export function getInstalledApps({ appViewsByPolicy, selectedPolicy, policies, $vuntangle, installingApps = {} }) {
  // Guard clauses
  if (!appViewsByPolicy || !selectedPolicy) {
    return []
  }

  // Create policy map for O(1) lookups
  const policyMap = policies.reduce((acc, policy) => {
    acc[policy.policyId] = policy
    return acc
  }, {})

  // Build policy hierarchy chain (selected -> parent -> grandparent -> root)
  const policyHierarchy = buildPolicyChain(selectedPolicy, policyMap)

  // Collect all app instances from the policy hierarchy
  const allApps = policyHierarchy.reduce((acc, policyId) => {
    const view = appViewsByPolicy[policyId] // O(1) lookup
    return acc.concat(view ? view.instances : [])
  }, [])

  // Get unique app names (exclude null policyId which are service apps)
  const uniqueAppNames = [...new Set(allApps.filter(app => app.policyId !== null).map(app => app.appName))]

  // Build enriched app objects
  let apps = uniqueAppNames
    .map(appName => {
      // Find the app in the policy hierarchy (check selected policy first, then parents)
      for (const policyId of policyHierarchy) {
        const view = appViewsByPolicy[policyId] // O(1) lookup

        if (!view) continue

        const app = view.instances.find(a => a.appName === appName)

        if (app) {
          // Determine if this app is from a parent policy
          const parentPolicyName =
            app.policyId && app.policyId !== selectedPolicy.policyId ? policyMap[app.policyId]?.name : null

          // Get app properties
          const appProperties = view.appProperties.find(prop => prop.name === appName)

          // Enrich app with UI metadata
          return enrichAppInstance(app, view, appProperties, parentPolicyName, installingApps, $vuntangle)
        }
      }
      return null
    })
    .filter(Boolean) // Remove null entries

  // Add apps that are currently being installed but not yet instantiated by backend
  // This ensures installing apps always show with loader, even if backend hasn't created instance yet
  const currentPolicyView = appViewsByPolicy[selectedPolicy.policyId]
  if (currentPolicyView) {
    Object.keys(installingApps).forEach(appName => {
      const installing = installingApps[appName]

      // Only add if:
      // 1. App is in 'progress' status (currently installing)
      // 2. App is being installed for the current policy
      // 3. App is not already in the apps list (avoid duplicates)
      if (
        installing.status === INSTALL_STATUS.PROGRESS &&
        installing.policyId === selectedPolicy.policyId &&
        !apps.find(a => a.appName === appName)
      ) {
        // Get app properties to build placeholder app object
        const appProperties = currentPolicyView.appProperties.find(prop => prop.name === appName)

        if (appProperties) {
          // Create placeholder app object for installing app
          const placeholderApp = {
            appName,
            policyId: selectedPolicy.policyId,
            displayName: appProperties.displayName || appName,
            viewPosition: appProperties.viewPosition || DEFAULT_VIEW_POSITION,
            hasPowerButton: false, // No power button while installing
            powerCls: '', // No power state while installing
            licenseMessage: '', // No license message needed during install
            installing: true, // Mark as installing
            parentPolicy: null, // Not inherited
            props: appProperties,
          }

          apps.push(placeholderApp)
        }
      }
    })
  }

  // Sort apps by view position and policy hierarchy
  apps = apps.sort((a, b) => {
    // Primary sort: View position (lower numbers first)
    if (a.viewPosition !== b.viewPosition) {
      return a.viewPosition - b.viewPosition
    }

    // Secondary sort: Policy hierarchy (apps from parent policies first)
    // Lower policyId = higher in hierarchy = should appear first
    return a.policyId - b.policyId
  })

  return apps
}

/**
 * Gets installable apps for a policy
 *
 * Returns apps that can be installed for the selected policy.
 * Only FILTER type apps are included (SERVICE apps are excluded).
 * Apps with 'finish' installation status are included to show success state.
 *
 * @param {Object} params - Function parameters
 * @param {Object<number, Object>} params.appViewsByPolicy - Normalized app views keyed by policyId
 * @param {Object} params.selectedPolicy - Currently selected policy object
 * @param {Object} [params.installingApps={}] - Map of apps currently being installed
 * @returns {Array<Object>} Sorted array of installable app objects
 *
 * @example
 * const apps = getInstallableApps({
 *   appViewsByPolicy: { 1: {...} },
 *   selectedPolicy: { policyId: 1 },
 *   installingApps: { 'web-filter': { status: 'progress', policyId: 1 } }
 * })
 */
export function getInstallableApps({ appViewsByPolicy, selectedPolicy, installingApps = {} }) {
  // Guard clauses
  if (!appViewsByPolicy || !selectedPolicy) {
    return []
  }

  const policyView = appViewsByPolicy[selectedPolicy.policyId] // O(1) lookup

  if (!policyView) {
    return []
  }

  const installableApps = []
  const addedApps = new Set() // Track apps to avoid duplicates

  // Add apps from backend's installable list
  // Only FILTER type apps are shown (SERVICE apps are excluded)
  policyView.installable.forEach(appName => {
    const app = policyView.appProperties.find(a => a.name === appName)

    if (app && app.type === APP_TYPE.FILTER) {
      installableApps.push({
        name: app.name,
        displayName: app.displayName,
        description: appDescription[app.name] || '',
        route: `#apps/${policyView.policyId}/${app.name}`,
        viewPosition: app.viewPosition || DEFAULT_VIEW_POSITION,
      })
      addedApps.add(app.name)
    }
  })

  // Add apps with 'finish' status that were just installed
  // These apps may no longer be in installable list but need to show success icon
  Object.keys(installingApps).forEach(appName => {
    const installing = installingApps[appName]

    // Only add if:
    // 1. Status is 'finish' (installation completed)
    // 2. Policy matches selected policy
    // 3. Not already added from installable list
    if (
      installing.status === INSTALL_STATUS.FINISH &&
      installing.policyId === selectedPolicy.policyId &&
      !addedApps.has(appName)
    ) {
      const app = policyView.appProperties.find(a => a.name === appName)

      if (app && app.type === APP_TYPE.FILTER) {
        installableApps.push({
          name: app.name,
          displayName: app.displayName,
          description: appDescription[app.name] || '',
          route: `#apps/${policyView.policyId}/${app.name}`,
          viewPosition: app.viewPosition || DEFAULT_VIEW_POSITION,
        })
      }
    }
  })

  // Sort by view position (ascending)
  const sortedApps = installableApps.sort((a, b) => a.viewPosition - b.viewPosition)

  return sortedApps
}
