import { ActionType } from './constants'

export default Object.freeze({
  [ActionType.Accept]: {
    text: 'action_accept',
    icon: 'mdi-check',
    iconColor: 'green',
  },
  [ActionType.Drop]: {
    text: 'action_drop',
    icon: 'mdi-arrow-down',
    iconColor: 'red',
  },
  [ActionType.Reject]: {
    text: 'action_reject',
    icon: 'mdi-close',
    iconColor: 'orange',
  },
  [ActionType.Masquerade]: {
    text: 'action_masquerade',
    icon: 'mdi-guy-fawkes-mask',
  },
  [ActionType.SourceAddress]: {
    text: 'new_source',
    icon: 'mdi-arrow-bottom-right',
  },
  [ActionType.DestinationAddress]: {
    text: 'new_destination',
    icon: 'mdi-arrow-top-right',
  },
  [ActionType.Priority]: {
    text: 'priority',
    icon: 'mdi-sort',
  },
  [ActionType.WanPolicy]: {
    icon: 'mdi-wan',
  },
  [ActionType.Configuration]: {
    icon: 'mdi-tune',
  },

  [ActionType.LimitExceed]: {
    text: 'limit_exceed_action',
    icon: 'mdi-wan',
  },
  [ActionType.Return]: {
    text: 'return',
    icon: 'mdi-circle',
  },
  [ActionType.Bypass]: {
    text: 'bypass',
    icon: 'mdi-debug-step-over',
  },
})
