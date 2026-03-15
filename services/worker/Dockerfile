#image we are using
FROM golang:1.23-bookworm AS builder

#setting our working directory
WORKDIR /app
COPY . /app

#build commands
RUN go build -o /bin/app

#run commands
CMD ["/bin/app"]
