import http from './http'

const api = {
  async get(url, params) {
    try {
      const response = await http.get(url, { params })
      return response?.data
    } catch (ex) {
      console.log(ex)
    }
  },

  async post(url, data, params = null) {
    const bodyFormData = new FormData()
    Object.entries(data).forEach(([key, value]) => {
      bodyFormData.append(key, value)
    })

    let response
    const httpOptions = {
      url,
      method: 'POST',
      data: bodyFormData,
      params,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    }

    try {
      response = await http(httpOptions)
      return response
    } catch (ex) {
      console.log(ex)
    }
  },
}

export default api
