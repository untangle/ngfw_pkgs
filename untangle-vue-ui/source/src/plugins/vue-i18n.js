import Vue from 'vue'
import VueI18n from 'vue-i18n'
import { dateTimeFormats, vuntangleEnLocale, vuntangleDeLocale, vuntangleJaLocale } from 'vuntangle'
import { ngfwEnLocale, ngfwDeLocale, ngfwJaLocale } from 'vuntangle/ngfw-locales'
import vuntangle from '@/plugins/vuntangle'
import { vuntangleEnLocale1 } from '@/locales'

Vue.use(VueI18n)

// The application instance owns component $t() calls. The vuntangle instance
// used by shared utilities and $vuntangle.$t() is separate, so every NGFW
// locale must be registered in both instances before either entry point
// mounts Vue.
const i18n = new VueI18n({
  locale: 'en',
  fallbackLocale: 'en',
  messages: {
    en: { ...vuntangleEnLocale, ...vuntangleEnLocale1 },
    de: vuntangleDeLocale,
    ja: vuntangleJaLocale,
  },
  silentTranslationWarn: true,
  dateTimeFormats,
})

const ngfwLocales = {
  en: ngfwEnLocale,
  de: ngfwDeLocale,
  ja: ngfwJaLocale,
}

// The common locale files stay in the normal locale buckets. NGFW-specific
// messages are opt-in and merged into matching en/de/ja buckets only by the
// NGFW host application.
Object.entries(ngfwLocales).forEach(([locale, messages]) => {
  i18n.mergeLocaleMessage(locale, messages)
  vuntangle.mergeLocaleMessages(locale, messages)
})

/**
 * i18n.availableLocales is an array of language codes: ['en', 'fr']
 * We want to able to show language selection with labels that describe the language rather than a code
 */
i18n.availableLocalesForUI = [
  {
    language: 'English (US)',
    code: 'en',
  },
  {
    language: 'Deutsch (DE)',
    code: 'de',
  },
  {
    language: 'Japan (JA)',
    code: 'ja',
  },
]

/**
 * Set the current used locale (language) code
 */
i18n.setLocale = locale => {
  const isLocaleAvailable = i18n.availableLocalesForUI.some(availableLocale => availableLocale.code === locale)
  // set the input locale only if it is available, or else set english
  const localeToSet = isLocaleAvailable ? locale : 'en'
  localStorage.setItem('i18n', localeToSet)
  i18n.locale = localeToSet
  vuntangle.locale = localeToSet
}

i18n.setLocale(localStorage.getItem('i18n') || 'en')
export default i18n
