import http from 'http';
import {sleep} from 'k6';

export const options = {
  vus : 2000, //Number of Virtual Users
  duration: '30s', // Test duration
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
  },
};

export default function () {
  http.get('http://localhost:8080/');
  sleep(1);
}   


// run command: k6 run test.js