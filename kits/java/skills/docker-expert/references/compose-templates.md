# Docker Compose Templates & .dockerignore

## Production Compose: Spring Boot + PostgreSQL + Redis

```yaml
services:
  app:
    build:
      context: .
      target: runtime
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/appdb
      SPRING_DATASOURCE_USERNAME: appuser
      SPRING_DATASOURCE_PASSWORD_FILE: /run/secrets/db_password
      SPRING_DATA_REDIS_HOST: redis
      SPRING_DATA_REDIS_PORT: 6379
      SPRING_PROFILES_ACTIVE: prod
    secrets:
      - db_password
    networks:
      - frontend
      - backend
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    restart: unless-stopped

  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser -d appdb"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - backend
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

volumes:
  postgres_data:
  redis_data:

secrets:
  db_password:
    external: true
```

## Development Override (docker-compose.override.yml)

```yaml
services:
  app:
    build:
      context: .
      target: build
    volumes:
      - .:/app
      - app-build-cache:/app/target
    environment:
      SPRING_PROFILES_ACTIVE: dev
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/appdb
      SPRING_DATASOURCE_USERNAME: appuser
      SPRING_DATASOURCE_PASSWORD: devpass
      SPRING_DATA_REDIS_HOST: redis
      SPRING_DATA_REDIS_PORT: 6379
    ports:
      - "8080:8080"
      - "8000:8000"   # Java debug port
    command: mvn spring-boot:run -Dspring-boot.run.jvmArguments="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000"

  postgres:
    environment:
      POSTGRES_PASSWORD: devpass
    ports:
      - "5432:5432"

  redis:
    ports:
      - "6379:6379"

volumes:
  app-build-cache:
```

## .dockerignore

```
# Build output
target/
build/

# IDE
.idea/
*.iml
.vscode/

# Git
.git/
.gitignore

# OS
.DS_Store
Thumbs.db

# Docker
Dockerfile*
docker-compose*

# Documentation
*.md
docs/

# Logs
*.log
logs/

# Test artifacts
test-results/
coverage/
```
