import Vue from 'vue'
import VueI18n from 'vue-i18n'
import { dateTimeFormats, vuntangleEnLocale, vuntangleDeLocale, vuntangleJaLocale } from 'vuntangle'
import vuntangle from '@/plugins/vuntangle'

Vue.use(VueI18n)

const i18n = new VueI18n({
  locale: 'en',
  fallbackLocale: {
    'en': ['vuntangleEnLocale'],
    'de': ['vuntangleDeLocale'],
    'ja': ['vuntangleJaLocale'],
  },
  messages: {
    vuntangleEnLocale,
    vuntangleDeLocale,
    vuntangleJaLocale,
  },
  silentTranslationWarn: true,
  dateTimeFormats,
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
  localStorage.setItem('i18n', locale)
  i18n.locale = locale
  vuntangle.locale = locale
}

i18n.setLocale(localStorage.getItem('i18n') || 'en')
export default i18n
