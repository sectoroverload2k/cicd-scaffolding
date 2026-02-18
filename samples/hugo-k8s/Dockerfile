FROM hugomods/hugo:latest AS builder

ARG VERSION=1.0.0

WORKDIR /src
COPY . .
RUN hugo --minify

FROM nginx:alpine

LABEL org.opencontainers.image.version="${VERSION}"

COPY --from=builder /src/public /usr/share/nginx/html

# Add health check file
RUN echo "ok" > /usr/share/nginx/html/health

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1
