<template>
  <v-navigation-drawer
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
        <!--Mini Menu Activated-->
        <v-list-item v-for="item in rootNavItems" :key="item.to" :to="item.to">
          <v-tooltip right content-class="root-nav-tooltip">
            <template #activator="{ on }">
              <v-list-item-content @mouseenter="reportsMiniActive = false" v-on="on">
                <v-list-item-icon class="mr-4 justify-center align-self-center`">
                  <v-icon dense v-text="item.icon" />
                </v-list-item-icon>
              </v-list-item-content>
            </template>
            <span class="text-uppercase">{{ $t(item.name) }}</span>
          </v-tooltip>
        </v-list-item>
      </template>
      <template v-else>
        <!--Expanded Menu Activated-->
        <v-list-item v-for="item in rootNavItems" :key="item.to" :to="item.to" @mouseenter="reportsMiniActive = false">
          <v-list-item-icon class="mr-4 justify-center align-self-center`">
            <v-icon dense v-text="item.icon" />
          </v-list-item-icon>
          <v-list-item-title class="text-uppercase">{{ $t(item.name) }}</v-list-item-title>
        </v-list-item>
      </template>

      <v-divider class="my-2" />

      <v-subheader v-if="!mini" class="text-uppercase caption ml-1">{{ $t('settings') }}</v-subheader>

      <template v-if="!mini">
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
      <template v-else>
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
              @mouseenter="reportsMiniActive = false"
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
    </v-list>
  </v-navigation-drawer>
</template>
<script>
  export default {
    data() {
      return {
        reportsActive: false, // flag if reports is expanded
        minWidth: 255,
        rootNavItems: [{ name: 'dashboard', to: '/', icon: 'mdi-view-dashboard' }],

        settingsNavItems: [
          {
            name: 'network',
            icon: 'mdi-lan',
            active: false,
            match: '/settings/network',
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
              { name: 'administration', to: '/settings/system/administration' },
              { name: 'events', to: '/settings/system/events' },
              { name: 'email_menu', to: '/settings/system/email' },
              { name: 'logging', to: '/settings/system/logging' },
              { name: 'Local Directory', to: '/settings/system/local-directory' },
              { name: 'upgrade', to: '/settings/system/upgrade' },
              { name: 'about', to: '/settings/system/about' },
            ],
          },
          {
            name: 'services',
            icon: 'mdi-apps',
            active: false,
            items: [
              { name: 'dynamic_blocklist', to: '/settings/services/dynamic-blocklist' }, // uncomment for development
            ],
          },
        ],
        reportsNavItems: [
          {
            name: 'bandwidth',
            active: false,
            match: '/reports/bandwidth',
            items: [
              { name: 'clients', to: '/reports/bandwidth/clients' },
              { name: 'server_ports', to: '/reports/bandwidth/server-ports' },
              { name: 'applications', to: '/reports/bandwidth/applications' },
            ],
          },
          {
            name: 'wan_performance',
            active: false,
            match: '/reports/wan-performance',
            items: [
              { name: 'usage', to: '/reports/wan-performance/usage' },
              { name: 'packet_loss', to: '/reports/wan-performance/packet-loss' },
              { name: 'latency', to: '/reports/wan-performance/latency' },
              { name: 'jitter', to: '/reports/wan-performance/jitter' },
            ],
          },
          {
            name: 'sessions',
            active: false,
            match: '/reports/sessions',
            items: [
              { name: 'sessions', to: '/reports/sessions/sessions' },
              { name: 'wan_routing', to: '/reports/sessions/wan-routing' },
            ],
          },
          {
            name: 'threat_prevention',
            active: false,
            match: '/reports/threat-prevention',
            items: [
              { name: 'blocked_summary', to: '/reports/threat-prevention/blocked-summary' },
              { name: 'blocked_addresses', to: '/reports/threat-prevention/blocked-addresses' },
            ],
          },
          {
            name: 'web_filter',
            active: false,
            match: '/reports/web-filter',
            items: [
              { name: 'summary', to: '/reports/web-filter/summary' },
              { name: 'visited_sites', to: '/reports/web-filter/visited-sites' },
            ],
          },
          {
            name: 'geoip_filtdnser',
            active: false,
            match: '/reports/geoip-filter',
            items: [
              { name: 'blocked_sessions', to: '/reports/geoip-filter/blocked-sessions' },
              { name: 'blocked_countries_outbound', to: '/reports/geoip-filter/blocked-outbound' },
              { name: 'blocked_countries_inbound', to: '/reports/geoip-filter/blocked-inbound' },
              { name: 'distribution_map', to: '/reports/geoip-filter/distribution-map' },
            ],
          },
          {
            name: 'application_control',
            active: false,
            match: '/reports/application-control',
            items: [{ name: 'applications', to: '/reports/application-control/applications' }],
          },
          {
            name: 'captive_portal',
            active: false,
            match: '/reports/captive-portal',
            items: [
              { name: 'captive_portal_summary', to: '/reports/captive-portal/captive-portal-summary' },
              { name: 'captive_portal_events', to: '/reports/captive-portal/captive-portal-events' },
            ],
          },
        ],
        reportsMiniActive: false,
      }
    },
    computed: {
      mini() {
        return this.$store.state.miniDrawer
      },
    },
    watch: {
      // opens specific submenu group to match route on expanding nav or page load
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
          this.reportsActive = this.$route.path.includes('/reports')
        },
      },
    },
    methods: {
      // returns class to highlight a collapsed group on route match
      isCollapsedActive(match, active) {
        return this.$route.path.includes(match) && !active ? 'group-active' : ''
      },
      // returns class to highlight an item/group on route match
      isActive(match) {
        return this.$route.path.includes(match) ? 'item-active' : ''
      },
      // method used to keep reports submenu open in mini mode
      reportsMiniLeaveMenu() {
        this.reportsMiniActive = this.reportsNavItems.findIndex(item => item.active) >= 0
      },
    },
  }
</script>

<!--
  styling needed for highlighting active items
  `item-active` and `group-active` are custom classes overriding vuetify css
  using vuetify classes specificity to avoid `!important`
  0.24 opacity is the one used by vuetify, so keeping it the same
-->
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
