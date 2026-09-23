// Error handling.
//
// Routes throw ApiError (or anything else) and a single middleware turns it
// into a response. Previously each of ~50 handlers had its own try/catch that
// echoed `err.message` to the client, which leaked stack details and Mongo
// internals on any unexpected failure.

class ApiError extends Error {
  constructor(status, message, details) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.details = details;
    this.expected = true;
  }
}

const badRequest = (message, details) => new ApiError(400, message, details);
const unauthorized = (message = 'Not authenticated') => new ApiError(401, message);
const forbidden = (message = 'Not allowed') => new ApiError(403, message);
const notFound = (message = 'Not found') => new ApiError(404, message);
const conflict = (message, details) => new ApiError(409, message, details);
const tooMany = (message = 'Too many requests') => new ApiError(429, message);

// Wraps an async handler so a rejected promise reaches the error middleware.
// Express 5 forwards rejections on its own, but being explicit keeps the
// behaviour identical if the app is ever run on Express 4.
function asyncHandler(fn, { transactional = true } = {}) {
  return (req, res, next) =>
    Promise.resolve()
      .then(() => {
        // AI generation has a remote side effect and uses its own reservation flow.
        if (
          transactional &&
          req.user &&
          ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method) &&
          !req.originalUrl.startsWith('/api/ai')
        ) {
          return require('./mutations').executeMutation(req, res, fn);
        }
        return fn(req, res, next);
      })
      .catch(next);
}

function notFoundHandler(req, res) {
  res.status(404).json({ message: `No route for ${req.method} ${req.path}` });
}

function errorHandler(logger = console) {
  // eslint-disable-next-line no-unused-vars -- Express identifies error middleware by arity
  return (err, req, res, next) => {
    const status = err.expected ? err.status : 500;

    if (!err.expected) {
      logger.error(`[${req.method} ${req.path}]`, err);
    }

    const body = {
      message: err.expected ? err.message : 'Something went wrong on our end',
    };
    if (err.details) body.details = err.details;
    // The raw message is useful in development and a liability in production.
    if (!err.expected && process.env.NODE_ENV !== 'production') {
      body.error = err.message;
      body.stack = err.stack;
    }

    res.status(status).json(body);
  };
}

module.exports = {
  ApiError,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  tooMany,
  asyncHandler,
  notFoundHandler,
  errorHandler,
};
