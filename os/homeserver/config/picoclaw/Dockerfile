FROM golang:alpine AS builder
RUN apk add --no-cache git make
RUN git clone https://github.com/sipeed/picoclaw /src
WORKDIR /src
RUN make build

FROM alpine:3.21
RUN apk add --no-cache ca-certificates tzdata curl
COPY --from=builder /src/build/picoclaw /usr/local/bin/picoclaw
RUN adduser -D -u 1000 picoclaw
USER picoclaw
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:18790/health || exit 1
CMD ["picoclaw", "gateway"]
