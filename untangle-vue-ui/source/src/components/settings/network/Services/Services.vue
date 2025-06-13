<template>
  <ConfigurationLayout :title="$t('Services')" :is-dirty="isDirty" :on-save="onSave" :validate="validate">
    <ValidationObserver ref="obs">
      <u-section :title="$t('Local Services')">
        <v-list dense class="py-0">
          <p>
            {{
              $vuntangle.$t(
                'The specified HTTPS port will be forwarded from all interfaces to the local HTTPS server to provide administration and other services.',
              )
            }}
          </p>
          <!-- HTTPS Port -->
          <v-row dense align="center">
            <v-col cols="4">
              <div class="d-flex align-center">
                <span class="font-weight-bold mr-2">HTTPS Port:</span>
                <ValidationProvider v-slot="{ errors }" rules="required|port">
                  <u-text-field v-model.number="settingsCopy.httpsPort" type="number" dense required>
                    <template v-if="errors.length" #append>
                      <u-errors-tooltip :errors="errors" />
                    </template>
                  </u-text-field>
                </ValidationProvider>
              </div>
            </v-col>
          </v-row>

          <!-- HTTP Port -->
          <p class="mt-8">
            {{
              $vuntangle.$t(
                'The specified HTTP port will be forwarded on non-WAN interfaces to the local HTTP server to provide administration, blockpages, and other services.',
              )
            }}
          </p>
          <v-row dense align="center" class="mt-6">
            <v-col cols="4">
              <div class="d-flex align-center">
                <span class="font-weight-bold mr-4">HTTP Port:</span>
                <ValidationProvider v-slot="{ errors }" rules="required|port">
                  <u-text-field v-model.number="settingsCopy.httpPort" type="number" dense required>
                    <template v-if="errors.length" #append>
                      <u-errors-tooltip :errors="errors" />
                    </template>
                  </u-text-field>
                </ValidationProvider>
              </div>
            </v-col>
          </v-row>
        </v-list>
      </u-section>
    </ValidationObserver>
  </ConfigurationLayout>
</template>

<script>
  import { cloneDeep } from 'lodash'
  import settingsMixin from '../../settingsMixin'
  import ConfigurationLayout from '../../../Reusable/ConfigurationLayout.vue'
  import Util from '@/util/setupUtil'

  export default {
    name: 'Services',
    components: { ConfigurationLayout },
    mixins: [settingsMixin],

    data() {
      return {
        isSaving: false,
      }
    },
    created() {
      this.settings = this.$store.getters['settings/networkSetting']
      this.settingsCopy = cloneDeep(this.settings)
    },
    methods: {
      async validate() {
        return await this.$refs.obs.validate()
      },

      patchRpcListStructure(obj, fields = []) {
        fields.forEach(key => {
          if (Array.isArray(obj[key])) {
            obj[key] = {
              javaClass: 'java.util.LinkedList',
              list: obj[key],
            }
          }
        })
        return obj
      },

      async onSave() {
        const isValid = await this.validate()
        if (!isValid) return

        this.isSaving = true
        try {
          const fullSettings = cloneDeep(this.settingsCopy)
          await this.patchRpcListStructure(fullSettings, ['interfaces'])

          console.log('Sanitized settings being sent:', this.settingsCopy)

          // Call store
          await this.$store.dispatch('settings/setNetworkSettings', fullSettings)
        } catch (e) {
          Util.handleException(e)
        } finally {
          this.isSaving = false
        }
      },
    },
  }
</script>
