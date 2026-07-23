const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { createProxyMiddleware } = require('http-proxy-middleware');
const jwt = require('jsonwebtoken');

const PORT = process.env.PORT || 8080;
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-key-change-in-production-12345';
 
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

// JWT Authentication Middleware
const authenticateJWT = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (authHeader) {
    const token = authHeader.split(' ')[1];
    if (token) {
      jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
          console.log('[Auth] Invalid JWT:', err.message);
          // Don't block the request, but don't attach user info.
          // Downstream services that require auth will fail.
          return next();
        }
        // Attach user info to the request for downstream services
        req.user = user;
        console.log('[Auth] JWT validated for user:', user.sub);
        next();
      });
    } else {
      next();
    }
  } else {
    next();
  }
}

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

    // Rewrite the path to remove the /api prefix.
    // e.g., /api/polls/some-slug -> /polls/some-slug
    pathRewrite: (path, req) => {
      // Use the original URL and remove the /api prefix to get the correct downstream path.
      return req.originalUrl.replace('/api', '');
    },

    on: {
      proxyReq: (proxyReq, req) => {
        console.log(`[Proxy] ${req.method} ${req.originalUrl}`);
        console.log(`Target : ${target}`);
        console.log(`Forward: ${proxyReq.path}`);

        // Add X-User-Id header if the user was authenticated
        if (req.user && req.user.sub) {
          proxyReq.setHeader('X-User-Id', req.user.sub);
        }

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

app.use('/api/auth', createServiceProxy(services.auth)); // Auth service is public

app.use('/api/users', authenticateJWT, createServiceProxy(services.users));

app.use('/api/polls', authenticateJWT, createServiceProxy(services.polls));

app.use(
  '/api/votes',
  voteLimiter,
  createServiceProxy(services.votes)
);

app.use('/api/results', authenticateJWT, createServiceProxy(services.results));

// -----------------------------------------------------------------------------
// Start Server
// -----------------------------------------------------------------------------

app.listen(PORT, () => {
  console.log(`🚀 API Gateway listening on port ${PORT}`);
});