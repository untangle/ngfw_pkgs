import i18n from 'vuntangle'

function addConditionHeaders(headers, types, selectedItem = '') {
  const conditions = []
  const headerMap = new Map()
  let currentCategory
  let selectedItemCategory
  let inserted = false
  let categoryMet = false

  headerMap.set('other', {
    text: 'other',
    inserted: false,
  })

  headers.forEach(header => {
    headerMap.set(header.prefix, {
      text: header.text,
      inserted: false,
    })
  })
  if (selectedItem) {
    const selectedItemPrefix = selectedItem.split('_')[0]
    if (headerMap.has(selectedItemPrefix)) {
      selectedItemCategory = headerMap.get(selectedItemPrefix).text
    } else {
      selectedItemCategory = 'other'
    }
  }
  types.forEach(type => {
    const prefix = type.split('_')[0]
    if (headerMap.has(prefix)) {
      if (!headerMap.get(prefix).inserted) {
        currentCategory = headerMap.get(prefix).text
        conditions.push({
          divider: true,
          header: i18n.t(headerMap.get(prefix).text.toLowerCase()),
          text: i18n.t(headerMap.get(prefix).text.toLowerCase()),
          value: prefix,
        })

        headerMap.set(prefix, {
          inserted: true,
        })
      }
    } else if (!headerMap.get('other').inserted) {
      currentCategory = 'other'
      conditions.push({
        divider: true,
        header: i18n.t('other'),
        text: i18n.t('other'),
        value: type.value,
      })

      headerMap.set('other', {
        inserted: true,
      })
    }

    if (selectedItemCategory) {
      if (selectedItemCategory === currentCategory) {
        // selectedItem belongs to this category
        categoryMet = true
        if (type > selectedItem && !inserted) {
          conditions.push({
            text: i18n.t(selectedItem.toLowerCase()),
            value: selectedItem,
          })
          inserted = true
        }
      } else if (categoryMet && !inserted) {
        // selectedItem was last type in the category so it should be added here before the new category
        conditions.splice(conditions.length - 1, 0, {
          text: i18n.t(selectedItem.toLowerCase()),
          value: selectedItem,
        })
        inserted = true
      }
    }
    conditions.push({
      text: i18n.t(type.toLowerCase()),
      value: type,
    })
  })
  if (!inserted && selectedItem) {
    // selectedItem was the last type in list so should be added here
    conditions.push({
      text: i18n.t(selectedItem.toLowerCase()),
      value: selectedItem,
    })
    inserted = true
  }
  return conditions
}

export { addConditionHeaders }
