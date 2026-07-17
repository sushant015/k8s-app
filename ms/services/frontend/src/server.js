const express = require('express');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

const PORT = process.env.PORT || 8080;
const API_GATEWAY_URL = process.env.API_GATEWAY_URL || 'http://api-gateway:8080';

const app = express();

app.use((req, res, next) => {
  console.log(`${req.method} ${req.originalUrl}`);
  next();
});

app.use('/api', createProxyMiddleware({
  target: API_GATEWAY_URL,
  changeOrigin: true,
}));

app.use(express.static(path.join(__dirname, 'public')));

app.get('/health', (_req, res) => {
  res.json({ status: 'UP', service: 'frontend-service' });
});

app.get('/config.js', (_req, res) => {
  res.type('application/javascript').send(`window.APP_CONFIG = { apiBaseUrl: '/api' };`);
});

app.get('*', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Frontend service listening on port ${PORT}`);
});
