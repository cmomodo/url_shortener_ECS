# Use the official Golang image as the base
FROM golang:1.23-alpine AS builder

# Set environment variables
ARG TARGETOS
ARG TARGETARCH

# Set working directory inside the container
WORKDIR /build

# Copy go.mod and go.sum files for dependency installation
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the entire application source
COPY . .

# Build the Go binary
RUN go build -ldflags "-w -s" -o /app .

# Final lightweight stage
FROM alpine:3.21 AS final

#we adding a label to point back to the reposit
LABEL org.opencontainers.image.source="https://github.com/your-org/url-shortener"

# Non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup


# Copy the compiled binary from the builder stage
COPY --from=builder --chown=appuser:appgroup /app /bin/app

#run non-root user
USER appuser

# Expose the application's port
EXPOSE 8081

#healthcheck before finalising stage
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8081/health || exit 1

# Run the application
CMD ["/bin/app"]
