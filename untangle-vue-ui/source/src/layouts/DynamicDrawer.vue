<!-- This component is required for rendering the sidebar in ExtJs project using iFrame. It can be removed once all the code is migrated to vue -->
<template>
  <v-navigation-drawer
    v-if="settingsNavItems.length > 0"
    app
    nav
    clipped
    :width="minWidth"
    disable-resize-watcher
    dark
    color="aristaBlue"
    :mini-variant="mini"
    mini-variant-width="56"
    permanent
    :expand-on-hover="false"
  >
    <v-list dense nav>
      <template v-if="mini">
        <v-menu
          v-for="(item, idx1) in settingsNavItems"
          :key="`settings-menu-${idx1}`"
          dark
          right
          offset-x
          nudge-top="6"
          nudge-left="3"
          open-on-hover
          :transition="false"
          content-class="drawer-content-menu"
        >
          <template #activator="{ on, attrs }">
            <v-list-item
              v-bind="attrs"
              href="#"
              :ripple="false"
              :class="isActive(item.match) ? 'v-list-item--active' : ''"
              v-on="on"
            >
              <v-list-item-icon class="justify-center">
                <v-icon dense>{{ item.icon }}</v-icon>
              </v-list-item-icon>
            </v-list-item>
          </template>
          <v-card flat class="ml-3" color="transparent" :min-width="minWidth">
            <v-list dense nav color="aristaBlue">
              <v-subheader class="text-uppercase caption">{{ $t(item.name) }}</v-subheader>
              <v-divider class="my-1" />
              <v-list-item v-for="(subItem, idx2) in item.items" :key="`reports-${idx1}-${idx2}`" :to="subItem.to">
                <v-list-item-title class="text-uppercase caption">{{ $t(subItem.name) }}</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-card>
        </v-menu>
      </template>
      <template v-else>
        <v-list-group
          v-for="(item, idx) in settingsNavItems"
          :key="`settings-${idx}`"
          v-model="item.active"
          :class="`${isCollapsedActive(item.match, item.active)} white--text`"
          :active-class="`${isActive(item.match)} white--text`"
        >
          <template #activator>
            <v-list-item-icon :id="`settings-${idx}`" class="mr-4 my-2 justify-center align-self-center">
              <v-icon dense v-text="item.icon" />
            </v-list-item-icon>
            <v-list-item-title class="text-uppercase">{{ $t(item.name) }}</v-list-item-title>
          </template>
          <v-list-item v-for="subItem in item.items" :key="subItem.name" :to="subItem.to" :class="`pl-12 white--text`">
            <v-list-item-title class="text-uppercase caption">
              {{ $t(subItem.name) }}
            </v-list-item-title>
          </v-list-item>
        </v-list-group>
      </template>
    </v-list>
    <template #prepend>
      <v-btn icon class="ma-2" @click="toggleMiniDrawer">
        <v-icon>
          {{ mini ? 'mdi-menu' : 'mdi-menu-open' }}
        </v-icon>
      </v-btn>
    </template>
  </v-navigation-drawer>
</template>

<script>
  import store from '@/store'
  export default {
    data() {
      return {
        minWidth: 255,
        allNavItems: [
          {
            name: 'network',
            icon: 'mdi-lan',
            active: false,
            match: '/settings/',
            items: [
              { name: 'interface', to: '/settings/network/interfaces' },
              { name: 'port_forward', to: '/settings/network/port-forward' },
              { name: 'nat', to: '/settings/network/nat' },
              { name: 'bypass', to: '/settings/network/bypass' },
              { name: 'dhcp', to: '/settings/network/dhcp' },
              { name: 'dns', to: '/settings/network/dns' },
              { name: 'advanced', to: '/settings/network/advanced' },
              { name: 'troubleshooting', to: '/settings/network/troubleshooting' },
            ],
          },
          {
            name: 'routing',
            icon: 'mdi-call-split',
            active: false,
            match: '/settings/routing',
            items: [
              { name: 'static_routes', to: '/settings/routing/routes' },
              { name: 'dynamic_routes', to: '/settings/routing/dynamicRoutes' },
            ],
          },
          {
            name: 'firewall',
            icon: 'mdi-shield-half-full',
            active: false,
            match: '/settings/firewall',
            items: [
              { name: 'filter', to: '/settings/firewall/filter' },
              { name: 'access', to: '/settings/firewall/access' },
              { name: 'denial_of_service', to: '/settings/firewall/denial-of-service' },
            ],
          },
          {
            name: 'system',
            icon: 'mdi-cog',
            active: false,
            match: '/settings/system',
            items: [
              { name: 'settings', to: '/settings/system/settings' },
              { name: 'logging', to: '/settings/system/logging' },
              { name: 'about', to: '/settings/system/about' },
              { name: 'upgrade', to: '/settings/system/upgrade' },
            ],
          },
          {
            name: 'services',
            icon: 'mdi-apps',
            active: false,
            items: [{ name: 'dynamic_blocklist', to: '/settings/services/dynamic-blocklist' }],
          },
        ],
      }
    },
    computed: {
      mini() {
        return this.$store.state.miniDrawer
      },
      settingsNavItems() {
        const path = this.$route.path
        if (
          path.includes('/settings/network') ||
          path.includes('/settings/routing') ||
          path.includes('/settings/firewall')
        ) {
          return this.allNavItems.filter(
            item => item.name === 'network' || item.name === 'routing' || item.name === 'firewall',
          )
        } else if (path.includes('/settings/system')) {
          return this.allNavItems.filter(item => item.name === 'system')
        }
        return []
      },
    },
    watch: {
      mini: {
        immediate: true,
        handler(value) {
          if (value) return
          this.settingsNavItems.forEach(item => {
            if (this.$route.path.includes(item.match)) {
              item.active = true
            } else {
              item.active = false
            }
          })
        },
      },
    },
    methods: {
      isCollapsedActive(match, active) {
        return this.$route.path.includes(match) && !active ? 'group-active' : ''
      },
      isActive(match) {
        return this.$route.path.includes(match) ? 'item-active' : ''
      },
      toggleMiniDrawer() {
        store.commit('SET_MINI_DRAWER', !store.state.miniDrawer)
      },
    },
  }
</script>

<style lang="scss">
  .item-active.v-list-group__header.v-list-item--active:not(:hover):not(:focus)::before,
  .item-active.v-list-item--link::before {
    opacity: 0.24;
    background-color: #fff;
  }
  .group-active .v-list-item--link::before {
    opacity: 0.24;
    background-color: #fff;
  }
  .root-nav-tooltip {
    width: 200px;
    background-color: $arista-blue !important;
    margin-left: 7px;
    font-size: 12px;
  }
</style>
