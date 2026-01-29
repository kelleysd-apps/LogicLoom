# Deployment Templates Reference

Reference configurations for devops-operations skill.

## Dockerfile (Node.js)

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD curl -f http://localhost:3000/health || exit 1
CMD ["npm", "start"]
```

## GitHub Actions CI/CD

```yaml
name: CI/CD Pipeline
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test
      - run: npm run build

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build
      - run: npm run deploy
```

## docker-compose

```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - NODE_ENV=production
    depends_on:
      - db
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

## Deployment Checklist

### Pre-Deployment
- [ ] Tests passing
- [ ] Linting passing
- [ ] Security scan passed
- [ ] Environment variables configured
- [ ] Database migrations ready

### Deployment
- [ ] Health checks configured
- [ ] Rollback plan documented
- [ ] Monitoring active
- [ ] Alerts configured

### Post-Deployment
- [ ] Smoke tests pass
- [ ] Metrics normal
- [ ] No error spikes
