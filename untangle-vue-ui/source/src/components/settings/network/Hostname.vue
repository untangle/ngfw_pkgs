<template>
  <v-container class="d-flex flex-column pa-2" fluid>
    <div style="border: 1px solid #ccc; border-radius: 8px; padding: 16px">
      <v-row>
        <v-col cols="2"><v-divider /></v-col>
        <span class="mx-2 font-weight-medium text-grey">Hostname</span>
        <v-col><v-divider /></v-col>
      </v-row>
      <v-row dense>
        <v-col cols="4">
          <span>Hostname : </span>
          <ValidationProvider v-slot="{ errors }">
            <u-text-field :label="$t('Hostname')" :error-messages="errors">
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
            <u-text-field :label="$t('address')" :error-messages="errors">
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
          <v-checkbox v-model="isDynDnsEnabled" class="mr-1 ml-2" hide-details dense style="margin-bottom: 0" />
          <span class="mt-1 mr-2 font-weight-medium text-grey">Dynamic DNS Service Configuration </span>
        </v-col>

        <v-col>
          <v-divider />
        </v-col>
      </v-row>
      <div style="border: 1px solid #ccc; border-radius: 8px; padding: 16px">
        <v-row cols="3">
          <v-col>
            <span>Service :</span>
            <ValidationProvider v-slot="{ errors }">
              <v-autocomplete
                v-model="installTypeSync"
                :items="typeOptions"
                outlined
                dense
                hide-details
                return-object
                placeholder="Select Type"
                :error-messages="errors"
              >
                <template v-if="errors.length" #append>
                  <u-errors-tooltip :errors="errors" />
                </template>
              </v-autocomplete>
            </ValidationProvider>
          </v-col>
          <v-col>
            <span>Username :</span>
            <ValidationProvider v-slot="{ errors }" rules="required">
              <v-autocomplete
                v-model="timezone"
                :items="timezones"
                outlined
                dense
                hide-details
                return-object
                :error-messages="errors"
              >
              </v-autocomplete>
            </ValidationProvider>
          </v-col>
          <v-col>
            <span>Password or API Token :</span>
            <ValidationProvider v-slot="{ errors }" :rules="{ email: true }">
              <u-text-field v-model="adminEmail" :error-messages="errors">
                <template v-if="errors.length" #append>
                  <u-errors-tooltip :errors="errors" />
                </template>
              </u-text-field>
            </ValidationProvider>
          </v-col>
          <v-col>
            <span>Hostname(s) :</span>
            <ValidationProvider v-slot="{ errors }" :rules="{ email: true }">
              <u-text-field v-model="adminEmail" :error-messages="errors">
                <template v-if="errors.length" #append>
                  <u-errors-tooltip :errors="errors" />
                </template>
              </u-text-field>
            </ValidationProvider>
          </v-col>
          <v-col>
            <span>Interface :</span>
            <ValidationProvider v-slot="{ errors }" :rules="{ email: true }">
              <u-text-field v-model="adminEmail" :error-messages="errors">
                <template v-if="errors.length" #append>
                  <u-errors-tooltip :errors="errors" />
                </template>
              </u-text-field>
            </ValidationProvider>
          </v-col>
        </v-row>
      </div>
      <p class="text-h7 mt-4 ml-2">
        The Public Address is the address/URL that provides a public location for the Arista Server. This address will
        be used in emails sent by the Arista Server to link back to services hosted on the Arista Server such as
        Quarantine Digests and OpenVPN Client emails.
      </p>
      <v-radio-group>
        <v-radio
          label="Use IP address from External interface (default)"
          value="AUTO"
          class="font-weight-medium text-body-2"
        ></v-radio>
        <div class="ml-8 mb-4 text-body-6 text--secondary">
          This works if your Arista Server has a routable public static IP address.
        </div>
        <v-radio label="Use Hostname" value="STATIC" class="font-weight-medium text-body-2"></v-radio>
        <div class="ml-8 mb-4 text-body-6 text--secondary">
          This is recommended if the Arista Server's fully qualified domain name looks up to its IP address both
          internally and externally. Current Hostname: arista.untangle.com
        </div>
        <v-radio label="Use Manually Specified Address" value="PPPOE" class="font-weight-medium text-body-2"></v-radio>
        <div class="ml-8 mb-4 text-body-6 text--secondary">
          This is recommended if the Arista Server is installed behind another firewall with a port forward from the
          specified hostname/IP that redirects traffic to the Arista Server.
        </div>
        <v-row>
          <v-col cols="4">
            <span>Hostname : </span>
            <ValidationProvider v-slot="{ errors }">
              <u-text-field :label="$t('Hostname')" :error-messages="errors">
                <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
              </u-text-field>
            </ValidationProvider>
          </v-col>
        </v-row>
      </v-radio-group>
    </div>
  </v-container>
</template>
