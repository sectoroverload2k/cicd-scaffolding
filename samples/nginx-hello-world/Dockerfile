FROM nginx:alpine

ARG VERSION=1.0.0

LABEL org.opencontainers.image.version="${VERSION}"

COPY html/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1
