const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { createProxyMiddleware } = require('http-proxy-middleware');

const PORT = process.env.PORT || 8080;

const services = {
  auth: process.env.AUTH_SERVICE_URL || 'http://auth-service:8080',
  users: process.env.USER_SERVICE_URL || 'http://user-service:8080',
  polls: process.env.POLL_SERVICE_URL || 'http://poll-service:8080',
  votes: process.env.VOTE_SERVICE_URL || 'http://vote-service:8080',
  results: process.env.RESULT_SERVICE_URL || 'http://result-service:8080',
};

const app = express();
app.use(helmet());
app.use(express.json());

app.use((req, res, next) => {
  console.log(`api-gateway: ${req.method} ${req.originalUrl}`);
  next();
});

app.get('/health', (_req, res) => res.json({ status: 'UP', service: 'api-gateway' }));

const voteLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  message: { error: 'Too many requests, please try again later' },
});

app.use('/api/auth', createProxyMiddleware({
  target: services.auth,
  changeOrigin: true,
  pathRewrite: { '^/api/auth': '/api/auth' },
}));

app.use('/api/users', createProxyMiddleware({
  target: services.users,
  changeOrigin: true,
  pathRewrite: { '^/api/users': '/api/users' },
}));

app.use('/api/polls', createProxyMiddleware({
  target: services.polls,
  changeOrigin: true,
  pathRewrite: (path) => path.replace(/^\/api\/polls/, '/api/polls'),
}));

app.use('/api/votes', voteLimiter, createProxyMiddleware({
  target: services.votes,
  changeOrigin: true,
  pathRewrite: { '^/api/votes': '/api/votes' },
}));

app.use('/api/results', createProxyMiddleware({
  target: services.results,
  changeOrigin: true,
  pathRewrite: { '^/api/results': '/api/results' },
}));

app.listen(PORT, () => {
  console.log(`API Gateway listening on port ${PORT}`);
});
