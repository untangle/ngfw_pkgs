import axios from 'axios'

const http = axios.create({
  withCredentials: true,
  headers: {
    'Content-Type': 'application/x-www-form-urlencoded',
  },
})

export default http
