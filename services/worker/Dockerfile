#image we are using
FROM golang:1.23-bookworm AS base

#setting our working directory
WORKDIR /home/nonroot/app
COPY --chown=nonroot:nonroot . /home/nonroot/app


#build commands
RUN go build -o /bin/app

#run commands
CMD ["/bin/app"]

#stage 2
FROM golang:1.23-bookworm AS builder

#set new working directory
WORKDIR /app
COPY go.mod go.sum ./


RUN go mod download
COPY . .
RUN go build -o /bin/app .

FROM debian:bookworm-slim AS final
COPY --from=builder /bin/app /bin/app

#expose health port
EXPOSE 8090
CMD ["/bin/app"]
