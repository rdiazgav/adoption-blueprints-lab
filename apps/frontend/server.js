'use strict';

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 3000;
const API_GATEWAY_URL = process.env.API_GATEWAY_URL || 'http://api-gateway:8080';

// Static assets
app.use(express.static('public'));

// Proxy all /api/* traffic to the api-gateway.
// Mounted at root (not '/api') so Express does not strip the /api prefix
// before forwarding — the gateway expects the full /api/... path.
app.use(
  createProxyMiddleware({
    target: API_GATEWAY_URL,
    changeOrigin: true,
    pathFilter: '/api/**',
    on: {
      error: (err, req, res) => {
        console.error('[proxy error]', err.message);
        res.status(502).json({ error: 'gateway unavailable', detail: err.message });
      },
    },
  })
);

// Local health — lets OpenShift probe the frontend pod without hitting the gateway
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'frontend' });
});

app.listen(PORT, () => {
  console.log(`CloudHop Travel frontend listening on port ${PORT}`);
  console.log(`Proxying /api to ${API_GATEWAY_URL}`);
});
