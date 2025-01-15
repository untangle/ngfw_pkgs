<template>
  <div>
    <p>{{ staticRoutes }}</p>
    <p>{{ lanInterfaces }}</p>
  </div>
  <!-- <static-routes-list
    :title="$t('static_routes')"
    :routes="staticRoutes"
    :interfaces="lanInterfaces"
    @edit-route="onEditRoute"
    @delete-route="onDeleteRoute"
  >
    <template #actions="{ updatedRoutes }">
      <u-btn :min-width="null" class="mr-2" to="/settings/routing/routes/add">{{ $t('add_static_route') }}</u-btn>
      <u-btn :min-width="null" :disabled="saveDisabled(updatedRoutes)" @click="onSave(updatedRoutes)">
        {{ $t('save') }}
      </u-btn>
    </template>
  </static-routes-list> -->
</template>
<script>
  import cloneDeep from 'lodash/cloneDeep'
  // import { StaticRoutesList } from 'vuntangle'
  import transform from '@/util/transform'

  export default {
    // components: { StaticRoutesList },
    computed: {
      staticRoutes: () => transform.staticRoutes.get(),
      lanInterfaces: ({ $store }) => $store.getters['settings/lanInterfaces'],
    },

    methods: {
      /**
       * if no changes detected (enabled/disabled route)
       * the `save` action button is disabled
       * @param {Array} updatedRoutes - edited routes
       */
      saveDisabled(updatedRoutes) {
        return this.routes.every((route, routeIndex) => route.enabled === updatedRoutes[routeIndex]?.enabled)
      },

      onEditRoute(index) {
        this.$router.push(`/settings/routing/routes/${index}`)
      },

      // delete route based on index
      async onDeleteRoute(index) {
        const routesCopy = cloneDeep(this.routes)
        routesCopy.splice(index, 1)
        this.$store.commit('SET_LOADER', true)
        const response = await this.$store.dispatch('settings/setRoutes', routesCopy)
        this.$store.commit('SET_LOADER', false)
        if (response) {
          this.$vuntangle.toast.add(this.$t('deleted_successfully', [this.$t('static_route')]))
        }
      },

      async onSave(updatedRoutes) {
        this.$store.commit('SET_LOADER', true)
        const response = await this.$store.dispatch('settings/setRoutes', updatedRoutes)
        this.$store.commit('SET_LOADER', false)
        if (response) {
          this.$vuntangle.toast.add(this.$t('saved_successfully', [this.$t('static_routes')]))
        }
      },
    },
  }
</script>
