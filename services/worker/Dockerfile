#build stage
FROM golang:1.23-bookworm AS builder

#set new working directory
WORKDIR /app
COPY go.mod go.sum ./


RUN go mod download
COPY . .
RUN go build -o /bin/app .

FROM gcr.io/distroless/base-debian12:nonroot
COPY --from=builder /bin/app /bin/app

#expose health port
EXPOSE 8090
CMD ["/bin/app"]
