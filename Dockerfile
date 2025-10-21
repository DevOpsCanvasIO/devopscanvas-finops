# DevOpsCanvas FinOps Services
FROM node:20-alpine

# Install system dependencies
RUN apk add --no-cache \
    curl \
    git \
    python3 \
    make \
    g++

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies for build)
RUN npm ci

# Copy application code
COPY . .

# Build application
RUN npm run build

# Remove dev dependencies
RUN npm prune --production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S finops -u 1001

# Change ownership
RUN chown -R finops:nodejs /app
USER finops

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["npm", "start"]