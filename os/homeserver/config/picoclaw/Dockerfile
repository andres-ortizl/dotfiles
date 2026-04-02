FROM golang:alpine AS builder
RUN apk add --no-cache git make
RUN git clone https://github.com/sipeed/picoclaw /src
WORKDIR /src
RUN make build-whatsapp-native

FROM sipeed/picoclaw:launcher
COPY --from=builder /src/build/picoclaw /usr/local/bin/picoclaw
