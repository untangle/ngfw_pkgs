<template>
  <v-container class="d-flex flex-column pa-2" fluid>
    <ValidationObserver v-slot="{ passes }">
      <v-row justify="end">
        <u-btn class="ma-4" :small="false" @click="passes(() => onSave('save'))">
          {{ $vuntangle.$t('save') }}
        </u-btn>
      </v-row>
      <div style="border: 2px solid #ccc; border-radius: 8px; padding: 16px">
        <v-row>
          <v-col cols="2"><v-divider /></v-col>
          <span class="mx-2 font-weight-medium text-grey">Hostname</span>
          <v-col><v-divider /></v-col>
        </v-row>
        <v-row dense>
          <v-col cols="4">
            <span>Hostname : </span>
            <ValidationProvider v-slot="{ errors }" rules="required">
              <u-text-field
                v-model="settings.hostname"
                :label="$vuntangle.$t('host_name')"
                maxlength="150"
                :error-messages="errors"
                @keydown="validateHostName"
              >
                <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
              </u-text-field>
            </ValidationProvider>
          </v-col>
          <v-col cols="6" class="pt-8">
            <span class="pa-2">
              <span class="text-grey ma-2">(eg: gateway)</span>
            </span>
          </v-col>
        </v-row>
        <v-row dense>
          <v-col cols="4">
            <span>Domain Name : </span>
            <ValidationProvider v-slot="{ errors }" :rules="{ required: true }">
              <u-text-field
                v-model="settings.domainName"
                :label="$vuntangle.$t('domain_name')"
                maxlength="150"
                :error-messages="errors"
              >
                <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
              </u-text-field>
            </ValidationProvider>
          </v-col>
          <v-col cols="6" class="pt-8">
            <span class="pa-2">
              <span class="text-grey ma-2">(eg: example.com)</span>
            </span>
          </v-col>
        </v-row>
      </div>
      <div>
        <v-row align="center" no-gutters>
          <v-col cols="2">
            <v-divider />
          </v-col>

          <v-col cols="auto" class="d-flex align-center">
            <v-checkbox
              v-model="settings.dynamicDnsServiceEnabled"
              class="mr-1 ml-2"
              hide-details
              dense
              style="margin-bottom: 0"
            />
            <span class="mt-1 mr-2 font-weight-medium text-grey">Dynamic DNS Service Configuration </span>
          </v-col>

          <v-col>
            <v-divider />
          </v-col>
        </v-row>
        <div
          v-show="settings.dynamicDnsServiceEnabled"
          style="border: 2px solid #ccc; border-radius: 8px; padding: 16px"
        >
          <v-row cols="3">
            <v-col>
              <span>Service :</span>
              <v-autocomplete
                v-model="settings.dynamicDnsServiceName"
                :items="serviceOptions"
                outlined
                dense
                hide-details
                return-object
                placeholder="Select Type"
                :error-messages="errors"
              >
              </v-autocomplete>
            </v-col>
            <v-col>
              <span>Username :</span>
              <u-text-field v-model="settings.dynamicDnsServiceUsername" :error-messages="errors"> </u-text-field>
            </v-col>
            <v-col>
              <span>Password or API Token :</span>
              <u-password v-model="settings.dynamicDnsServicePassword" :errors="errors" />
            </v-col>
            <v-col v-show="settings.dynamicDnsServiceName === 'cloudflare'">
              <span>Zone :</span>
              <u-text-field
                v-model="settings.dynamicDnsServiceZone"
                :error-messages="errors"
                :disabled="settings.dynamicDnsServiceName !== 'cloudflare'"
              >
              </u-text-field>
            </v-col>
            <v-col>
              <span>Hostname(s) :</span>
              <u-text-field v-model="settings.dynamicDnsServiceHostnames" :error-messages="errors"> </u-text-field>
            </v-col>
            <v-col>
              <span>Interface :</span>
              <!-- add below:items="allWanInterfaceNames" -->
              <v-select
                v-model="settings.dynamicDnsServiceWan"
                attach
                small-chips
                deletable-chips
                dense
                outlined
                hide-details
                :placeholder="$vuntangle.$t('select')"
              ></v-select>
            </v-col>
          </v-row>
        </div>
        <p class="text-h7 mt-4 ml-2">
          The Public Address is the address/URL that provides a public location for the Arista Server. This address will
          be used in emails sent by the Arista Server to link back to services hosted on the Arista Server such as
          Quarantine Digests and OpenVPN Client emails.
        </p>
        <v-radio-group v-model="settings.publicUrlMethod">
          <v-radio
            label="Use IP address from External interface (default)"
            value="external"
            class="font-weight-medium text-body-2"
          ></v-radio>
          <div class="ml-8 mb-4 text-body-6 text--secondary">
            This works if your Arista Server has a routable public static IP address.
          </div>
          <v-radio label="Use Hostname" value="hostname" class="font-weight-medium text-body-2"></v-radio>
          <div class="ml-8 mb-4 text-body-6 text--secondary">
            This is recommended if the Arista Server's fully qualified domain name looks up to its IP address both
            internally and externally. Current Hostname: arista.untangle.com
          </div>
          <v-radio
            label="Use Manually Specified Address"
            value="address_and_port"
            class="font-weight-medium text-body-2"
          ></v-radio>
          <div class="ml-8 mb-4 text-body-6 text--secondary">
            This is recommended if the Arista Server is installed behind another firewall with a port forward from the
            specified hostname/IP that redirects traffic to the Arista Server.
          </div>
          <v-row
            :class="{
              'opacity-50 pointer-events-none': settings.publicUrlMethod !== 'address_and_port',
            }"
          >
            <v-col cols="4">
              <span>IP/Hostname : </span>
              <ValidationProvider v-slot="{ errors }">
                <u-text-field
                  v-model="settings.publicUrlAddress"
                  :disabled="settings.publicUrlMethod !== 'address_and_port'"
                  :error-messages="errors"
                >
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
            <v-col cols="4">
              <span>Port : </span>
              <ValidationProvider v-slot="{ errors }" rules="required|min_value:1|max_value:128">
                <u-text-field
                  v-model.number="settings.publicUrlPort"
                  type="number"
                  :disabled="settings.publicUrlMethod !== 'address_and_port'"
                  :error-messages="errors"
                >
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
          </v-row>
        </v-radio-group>
      </div>
      <!-- <u-btn class="mt-4" @click="onSaveSystem">{{ $vuntangle.$t('save') }}</u-btn> -->
    </ValidationObserver>
  </v-container>
</template>
<script>
  import { extend } from 'vee-validate'
  export default {
    data() {
      return {
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
        settings: {
          'hostname': '',
          'domainName': '',
          'dynamicDnsServiceEnabled': false,
          'dynamicDnsServiceName': null,
          'dynamicDnsServiceUsername': null,
          'dynamicDnsServicePassword': null,
          'dynamicDnsServiceZone': null,
          'dynamicDnsServiceHostnames': null,
          'dynamicDnsServiceWan': 'Default',
          'publicUrlMethod': 'address_and_port',
        },
      }
    },
    created() {
      extend('valide_password', this.validatePasswordField)
    },
    methods: {
      validateHostName(event) {
        const allowedChars = /^[a-zA-Z0-9\-_=]$/
        if (event.key.length > 1) {
          return
        }
        if (!allowedChars.test(event.key)) {
          event.preventDefault()
        }
      },
      validatePasswordField(value) {
        if (!value) {
          return this.$t('Hostname must be specified.')
        }
        return true
      },
      allWanInterfaceNames() {
        // TODO Implementation getEnableInterfaceNames
      },
    },
  }
</script>
