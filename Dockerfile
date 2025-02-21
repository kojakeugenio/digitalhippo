# Stage 1: Dependencies
FROM node:18-alpine AS deps
RUN apk add --no-cache libc6-compat python3 make g++
WORKDIR /app

# Copy package files
COPY package.json yarn.lock ./

# Install dependencies
RUN yarn install --frozen-lockfile

# Stage 2: Builder
FROM node:18-alpine AS builder
WORKDIR /app

# Copy deps from previous stage
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Set environment variables for build
ENV NODE_ENV=production
ENV PAYLOAD_SECRET=fwrwer34243
ENV MONGODB_URL=mongodb://root:acdpOerZwacnjBD9JKoU0EUQUtcvD0xtEXFE0IFDHCEtQuHb0Q9P85j3VNyqCKWD@5.78.98.39:5433/?directConnection=true
ENV NEXT_PUBLIC_SERVER_URL=http://localhost:3000
ENV RESEND_API_KEY=re_jeKn1Pq7_4B7qFTLD5BvzfZHE1tUBHJ5a

# Clean and build steps in correct order with TypeScript path resolution
RUN rm -rf dist && \
    rm -rf src/payload-types.ts && \
    yarn build:payload && \
    yarn generate:types && \
    NODE_PATH=./ yarn build:server && \
    yarn copyfiles && \
    NODE_PATH=./ PAYLOAD_CONFIG_PATH=dist/payload.config.js NEXT_BUILD=true node dist/server.js

# Stage 3: Runner
FROM node:18-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PAYLOAD_SECRET=fwrwer34243
ENV MONGODB_URL=mongodb://root:acdpOerZwacnjBD9JKoU0EUQUtcvD0xtEXFE0IFDHCEtQuHb0Q9P85j3VNyqCKWD@5.78.98.39:5433/?directConnection=true
ENV NEXT_PUBLIC_SERVER_URL=http://localhost:3000
ENV RESEND_API_KEY=re_jeKn1Pq7_4B7qFTLD5BvzfZHE1tUBHJ5a

# Copy built assets from builder stage
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/yarn.lock ./yarn.lock
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/public ./public
COPY --from=builder /app/src/payload-types.ts ./src/payload-types.ts

# Create user for security
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
RUN chown -R nextjs:nodejs /app
USER nextjs

# Expose port
EXPOSE 3000

# Start the application
CMD ["yarn", "start"]