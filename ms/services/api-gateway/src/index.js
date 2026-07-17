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

// -----------------------------------------------------------------------------
// Middleware
// -----------------------------------------------------------------------------

app.use(helmet());

// Only required if the gateway needs to inspect request bodies.
// Since we're using it, we'll forward the body manually.
app.use(express.json());

// Request Logger
app.use((req, res, next) => {
  console.log(`\n==================================================`);
  console.log(`[Gateway] ${req.method} ${req.originalUrl}`);
  console.log(`==================================================`);
  next();
});

// -----------------------------------------------------------------------------
// Rate Limiter
// -----------------------------------------------------------------------------

const voteLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  message: {
    error: 'Too many requests, please try again later.',
  },
});

// -----------------------------------------------------------------------------
// Proxy Factory
// -----------------------------------------------------------------------------

function createServiceProxy(target) {
  return createProxyMiddleware({
    target,
    changeOrigin: true,

    // Preserve original URL
    pathRewrite: (path, req) => req.originalUrl,

    on: {
      proxyReq: (proxyReq, req) => {
        console.log(`[Proxy] ${req.method} ${req.originalUrl}`);
        console.log(`Target : ${target}`);
        console.log(`Forward: ${proxyReq.path}`);

        // Re-send JSON body because express.json() already consumed it
        if (
          req.body &&
          Object.keys(req.body).length > 0 &&
          ['POST', 'PUT', 'PATCH'].includes(req.method)
        ) {
          const bodyData = JSON.stringify(req.body);

          proxyReq.setHeader('Content-Type', 'application/json');
          proxyReq.setHeader('Content-Length', Buffer.byteLength(bodyData));

          proxyReq.write(bodyData);

          console.log('Body forwarded:', bodyData);
        }
      },

      proxyRes: (proxyRes, req) => {
        console.log(
          `[Response] ${req.method} ${req.originalUrl} -> ${proxyRes.statusCode}`
        );
      },

      error: (err, req, res) => {
        console.error(
          `[Proxy Error] ${req.method} ${req.originalUrl}`
        );
        console.error(err);

        if (!res.headersSent) {
          res.status(502).json({
            error: 'Bad Gateway',
            message: err.message,
          });
        }
      },
    },
  });
}

// -----------------------------------------------------------------------------
// Health Check
// -----------------------------------------------------------------------------

app.get('/health', (_req, res) => {
  res.json({
    status: 'UP',
    service: 'api-gateway',
  });
});

// -----------------------------------------------------------------------------
// API Routes
// -----------------------------------------------------------------------------

app.use('/api/auth', createServiceProxy(services.auth));

app.use('/api/users', createServiceProxy(services.users));

app.use('/api/polls', createServiceProxy(services.polls));

app.use(
  '/api/votes',
  voteLimiter,
  createServiceProxy(services.votes)
);

app.use('/api/results', createServiceProxy(services.results));

// -----------------------------------------------------------------------------
// Start Server
// -----------------------------------------------------------------------------

app.listen(PORT, () => {
  console.log(`🚀 API Gateway listening on port ${PORT}`);
});