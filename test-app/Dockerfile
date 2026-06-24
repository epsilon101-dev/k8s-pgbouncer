# syntax=docker/dockerfile:1.6
# Builder stage
FROM golang:1.22-alpine AS builder

WORKDIR /build

# Copy source and config
COPY go.mod ./
COPY main.go ./

# Download and resolve dependencies
RUN go mod tidy

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o gin-client .


# Runtime stage
FROM alpine:3.19

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
COPY --from=builder /build/gin-client /app/gin-client

# Set ownership to non-root user
RUN chown -R appuser:appgroup /app

USER appuser:appgroup
EXPOSE 8080

ENTRYPOINT ["/app/gin-client"]
