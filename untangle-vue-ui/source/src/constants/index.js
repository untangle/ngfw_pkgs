const booleanValues = { 'True': 'True', 'False': 'False' }
const booleanValueOptions = Object.entries(booleanValues).map(([k, v]) => ({ text: v, value: k }))

const invert = { true: 'is_not', false: 'is' }
const invertOptions = Object.entries(invert).map(([k, v]) => ({ text: v, value: k }))

const numeric = {
  '=': 'equals',
  '!=': 'not_equals',
  '>': 'greater_than',
  '<': 'less_than',
  '>=': 'greater_or_equal',
  '<=': 'less_or_equal',
}
const numericOptions = Object.entries(numeric).map(([k, v]) => ({ text: v, value: k }))

const textOperators = {
  '=': 'equals',
  '!=': 'not_equals',
  'substr': 'Contains',
  '!substr': 'Does not contain',
}
const textOperatorOptions = Object.entries(textOperators).map(([k, v]) => ({ text: v, value: k }))

const booleanOperators = { '=': 'is', '!=': 'is_not' }
const booleanOperatorOptions = Object.entries(booleanOperators).map(([k, v]) => ({ text: v, value: k }))

export { booleanValueOptions, invertOptions, numericOptions, textOperatorOptions, booleanOperatorOptions }
