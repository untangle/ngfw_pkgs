<template>
  <v-tabs v-model="activeTab" background-color="aristaBlue" dark>
    <v-tab v-for="(item, index) in settingsNavItems[0].items" :key="`tab-${index}`">
      {{ item.name.toUpperCase() }}
    </v-tab>
    <v-tabs-items v-model="activeTab">
      <v-tab-item v-for="(item, index) in settingsNavItems[0].items" :key="`tab-content-${index}`">
        <v-card flat>
          <v-card-text>
            <component :is="getComponentName(item.name)" />
          </v-card-text>
        </v-card>
      </v-tab-item>
    </v-tabs-items>
  </v-tabs>
</template>

<script>
  // network
  import Dhcp from '@/components/settings/network/Dhcp'
  import Dns from '@/components/settings/network/Dns.vue'
  import Interface from '@/components/settings/network/Interface.vue'

  export default {
    components: {
      Interface,
      Dhcp,
      Dns,
    },
    data() {
      return {
        activeTab: 0,
        settingsNavItems: [
          {
            name: 'network',
            icon: 'mdi-lan',
            items: [
              { name: 'interface', to: '/settings/network/interfaces' },
              { name: 'dhcp', to: '/settings/network/dhcp' },
              { name: 'dns', to: '/settings/network/dns' },
            ],
          },
        ],
      }
    },
    methods: {
      getComponentName(name) {
        switch (name) {
          case 'interface':
            return Interface
          case 'dhcp':
            return Dhcp
          case 'dns':
            return Dns
          default:
            return null // fallback
        }
      },
    },
  }
</script>
