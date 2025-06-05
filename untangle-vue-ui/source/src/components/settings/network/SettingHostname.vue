<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pl-14 pr-14 pa-8`">
    <ValidationObserver ref="obs">
      <div class="d-flex align-center">
        <v-spacer />
        <slot name="actions" :new-settings="settingsCopy" :is-dirty="isDirty" :validate="validate"></slot>
      </div>
      <v-row dense>
        <span class="mx-3 mb-3 font-weight-medium text-grey">Hostname</span>
        <v-col cols="11" class="ma-2"><v-divider /></v-col>
      </v-row>
      <div style="border: 2px solid #ccc; border-radius: 8px; padding: 16px">
        <v-row>
          <v-col cols="4">
            <ValidationProvider v-slot="{ errors }" rules="required">
              <u-text-field
                v-model="settingsCopy.hostName"
                :label="$vuntangle.$t('host_name')"
                maxlength="150"
                :error-messages="errors"
                @keydown="validateHostName"
              >
                <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
              </u-text-field>
            </ValidationProvider>
          </v-col>
          <v-col cols="6" class="pt-4">
            <span class="ma-1">
              <span class="text-grey ma-2">(eg: gateway)</span>
            </span>
          </v-col>
        </v-row>
        <v-row>
          <v-col cols="4">
            <ValidationProvider v-slot="{ errors }" :rules="{ required: true }">
              <u-text-field
                v-model="settingsCopy.domainName"
                :label="$vuntangle.$t('domain_name')"
                maxlength="150"
                :error-messages="errors"
              >
                <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
              </u-text-field>
            </ValidationProvider>
          </v-col>
          <v-col cols="6" class="pt-4">
            <span class="pa-1">
              <span class="text-grey ma-2">(eg: example.com)</span>
            </span>
          </v-col>
        </v-row>
      </div>
      <div>
        <v-row align="center" no-gutters>
          <v-col cols="auto" class="d-flex align-center mt-2">
            <v-checkbox
              v-model="settingsCopy.dynamicDnsServiceEnabled"
              class="ml-2"
              hide-details
              dense
              style="margin-bottom: 0"
            />
            <span class="mt-2 mr-6 font-weight-medium text-grey">
              <span class="mt-2">Dynamic DNS Service Configuration</span>
            </span>
          </v-col>

          <v-col cols="9" class="mt-3">
            <v-divider />
          </v-col>
        </v-row>
        <div
          v-show="settingsCopy.dynamicDnsServiceEnabled"
          class="mt-5"
          style="border: 2px solid #ccc; border-radius: 8px; padding: 16px"
        >
          <v-row dense>
            <v-col cols="4">
              <span>Service :</span>
              <v-autocomplete
                v-model="settingsCopy.dynamicDnsServiceName"
                :items="serviceOptions"
                outlined
                dense
                hide-details
                return-object
                placeholder="Select Type"
              >
              </v-autocomplete>
            </v-col>
          </v-row>
          <v-row dense>
            <v-col cols="4">
              <span>Username :</span>
              <u-text-field v-model="settingsCopy.dynamicDnsServiceUsername"> </u-text-field>
            </v-col>
          </v-row>
          <v-row dense>
            <v-col cols="4">
              <span>Password or API Token :</span>
              <u-password v-model="settingsCopy.dynamicDnsServicePassword" />
            </v-col>
          </v-row>
          <v-row dense>
            <v-col v-show="settingsCopy.dynamicDnsServiceName === 'cloudflare'" cols="6">
              <span>Zone :</span>
              <u-text-field
                v-model="settingsCopy.dynamicDnsServiceZone"
                :disabled="settingsCopy.dynamicDnsServiceName !== 'cloudflare'"
              >
              </u-text-field>
            </v-col>
          </v-row>
          <v-row dense>
            <v-col cols="4">
              <span>Hostname(s) :</span>
              <u-text-field v-model="settingsCopy.dynamicDnsServiceHostnames"> </u-text-field>
            </v-col>
          </v-row>
          <v-row dense>
            <v-col cols="4">
              <span>Interface :</span>
              <u-select v-model="settingsCopy.dynamicDnsServiceWan" :items="allWanInterfaceNames"> </u-select>
            </v-col>
          </v-row>
        </div>
        <p class="text-h7 mt-4 ml-2">
          {{
            `The Public Address is the address/URL that provides a public location for the ${rpc?.companyName} Server. This address will
          be used in emails sent by the ${rpc?.companyName} Server to link back to services hosted on the ${rpc?.companyName} Server such as
          Quarantine Digests and OpenVPN Client emails.`
          }}
        </p>
        <v-radio-group v-model="settingsCopy.publicUrlMethod">
          <v-radio
            label="Use IP address from External interface (default)"
            value="external"
            class="font-weight-bold text-body-2"
          ></v-radio>
          <div class="ml-10 mb-4 text-body-6 text--primary">
            <p>
              {{ `This works if your ${rpc?.companyName} Server has a routable public static IP address.` }}
            </p>
          </div>
          <v-radio label="Use Hostname" value="hostname" class="font-weight-bold text-body-2"></v-radio>
          <div class="ml-10 mb-4 text-body-6 text--primary">
            {{
              `This is recommended if the ${rpc?.companyName} Server's fully qualified domain name looks up to its IP address both
            internally and externally.`
            }}
            <br />
            {{ `Current Hostname: ` }} <i>{{ ` ${fullHostName} ` }}</i>
          </div>
          <v-radio
            label="Use Manually Specified Address"
            value="address_and_port"
            class="font-weight-bold text-body-2"
          ></v-radio>
          <div class="ml-10 mb-4 text-body-6 text--primary">
            {{
              `This is recommended if the ${rpc?.companyName} Server is installed behind another firewall with a port forward from the
            specified hostname/IP that redirects traffic to the ${rpc?.companyName} Server.`
            }}
          </div>
          <v-row dense>
            <v-col cols="4" class="ml-10">
              <span>IP/Hostname : </span>
              <ValidationProvider v-slot="{ errors }">
                <u-text-field
                  v-model="settingsCopy.publicUrlAddress"
                  :disabled="settingsCopy.publicUrlMethod !== 'address_and_port'"
                  :error-messages="errors"
                >
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
          </v-row>
          <v-row dense>
            <v-col cols="4" class="ml-10">
              <span>Port : </span>
              <ValidationProvider v-slot="{ errors }" rules="required">
                <u-text-field
                  v-model.number="settingsCopy.publicUrlPort"
                  type="number"
                  :disabled="settingsCopy.publicUrlMethod !== 'address_and_port'"
                  :error-messages="errors"
                >
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
          </v-row>
        </v-radio-group>
      </div>
    </ValidationObserver>
  </v-container>
</template>
<script>
  import cloneDeep from 'lodash/cloneDeep'
  import settingsMixin from '../settingsMixin'
  import Util from '@/util/setupUtil'
  export default {
    mixins: [settingsMixin],
    props: {
      isSaving: { type: Boolean, default: false },
    },
    data() {
      return {
        rpc: null,
        rpcAdmin: null,
        settingsCopy: null,
        allWanInterfaceNames: [],
        isModified: false,
        serviceOptions: [
          { value: 'easydns', text: 'EasyDNS' },
          { value: 'zoneedit', text: 'ZoneEdit' },
          { value: 'dyndns', text: 'DynDNS' },
          { value: 'namecheap', text: 'Namecheap' },
          { value: 'dslreports', text: 'DSL-Reports' },
          { value: 'dnspark', text: 'DNSPark' },
          { value: 'no-ip', text: 'No-IP' },
          { value: 'dnsomatic', text: 'DNS-O-Matic' },
          { value: 'freedns', text: 'FreeDNS' },
          { value: 'google', text: 'Google' },
          { value: 'googledomains', text: 'Google Domains' },
          { value: 'cloudflare', text: 'Cloudflare' },
          { value: 'duckdns', text: 'DuckDNS' },
        ],
      }
    },
    computed: {
      fullHostName() {
        const domain = this.settingsCopy.domainName
        const host = this.settingsCopy.hostName
        if (typeof domain === 'string' && domain.trim() !== '') {
          return `${host}.${domain}`
        } else {
          return host
        }
      },
    },
    created() {
      this.settingsCopy = cloneDeep(this.settings)
      this.rpc = Util.setRpcJsonrpc('admin')
      this.getEnableInterfaceNames()
      const startUpInfo = this.rpc.jsonrpc.UvmContext.getWebuiStartupInfo()
      Object.assign(this.rpc, startUpInfo)
    },
    methods: {
      isFieldModified(field) {
        return this.settings && !isEqual(this.settings[field], this.settingsCopy[field])
      },
      async validate() {
        const isValid = await this.$refs.obs.validate()
        return isValid
      },
      validateHostName(event) {
        const allowedChars = /^[a-zA-Z0-9\-_=]$/
        if (event.key.length > 1) {
          return
        }
        if (!allowedChars.test(event.key)) {
          event.preventDefault()
        }
      },
      getEnableInterfaceNames() {
        const enabledWanname = ['Default']
        const interfaces = this.rpc.networkManager.getEnabledInterfaces()

        interfaces.list.forEach(intf => {
          if (intf.isWan) {
            enabledWanname.push(intf.name)
          }
        })
        this.allWanInterfaceNames = enabledWanname
      },
    },
  }
</script>
<style scoped>
  .modified-field >>> .v-input__control {
    border: 1px solid red !important;
    background-color: #fff5f5;
  }
  .modified-field >>> .v-icon {
    color: red !important;
  }
</style>
