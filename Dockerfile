FROM alpine:3.8 as build

RUN set -x &&\
    wget -q https://github.com/transmission/transmission-releases/raw/master/transmission-2.94.tar.xz &&\
    {\
        echo "35442cc849f91f8df982c3d0d479d650c6ca19310a994eccdaa79a4af3916b7d  transmission-2.94.tar.xz"; \
    } > checksums.txt &&\
    sha256sum -c checksums.txt &&\
    tar -xJvf transmission-2.94.tar.xz &&\
    :

RUN set -x &&\
    apk add \
        g++ \
        curl-dev \
        libevent-dev \
        libbsd-dev \
        make \
        &&\
    :

RUN set -x &&\
    cd transmission-2.94 &&\
    CFLAGS="-Os" ./configure \
        --enable-utp \
        --with-inotify \
        --enable-cli \
        --disable-gtk \
        --disable-mac \
        --disable-wx \
        --disable-beos \
        --disable-nls \
        &&\
    make -j 4 &&\
    :

FROM golang:1.10-alpine as entrypoint

COPY entrypoint.go /go
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-s' -o entrypoint .


FROM scratch
LABEL maintainer="Oscar Latorre <oscarlatorre@pm.me>"

# $ objdump -s -j .interp /transmission-2.94/tramsission-daemon
# >
# >  /transmission-2.94/daemon/transmission-daemon:     file format elf64-x86-64
# >
# >  Contents of section .interp:
# >   0200 2f6c6962 2f6c642d 6d75736c 2d783836  /lib/ld-musl-x86
# >   0210 5f36342e 736f2e31 00                 _64.so.1.

# $ ldd /transmission-2.94/daemon/transmission-daemon
# >                          /lib/ld-musl-x86_64.so.1   (0x7f680aa37000)
# > libevent-2.1.so.6     => /usr/lib/libevent-2.1.so.6 (0x7f680a576000)
# > libcurl.so.4          => /usr/lib/libcurl.so.4      (0x7f680a308000)
# > libcrypto.so.43       => /lib/libcrypto.so.43       (0x7f6809f5d000)
# > libz.so.1             => /lib/libz.so.1             (0x7f6809d46000)
# > libc.musl-x86_64.so.1 => /lib/ld-musl-x86_64.so.1   (0x7f680aa37000)
# > libnghttp2.so.14      => /usr/lib/libnghttp2.so.14  (0x7f6809b25000)
# > libssh2.so.1          => /usr/lib/libssh2.so.1      (0x7f68098fd000)
# > libssl.so.45          => /lib/libssl.so.45          (0x7f68096b1000)

COPY --from=build /transmission-2.94/daemon/transmission-daemon /transmission-daemon
COPY --from=build \
    /lib/ld-musl-x86_64.so.1 \
    /lib/libcrypto.so.43 \
    /lib/libssl.so.45 \
    /lib/libz.so.1 \
    /lib/

COPY --from=build \
    /usr/lib/libcurl.so.4 \
    /usr/lib/libevent-2.1.so.6 \
    /usr/lib/libnghttp2.so.14 \
    /usr/lib/libssh2.so.1 \
    /usr/lib/

COPY --from=build \
    /transmission-2.94/web \
    /web

COPY --from=entrypoint \
    /go/entrypoint \
    /entrypoint

COPY settings.json /config/

ENV \
    TRANSMISSION_HOME=/config \
    TRANSMISSION_WEB_HOME=/web

EXPOSE 9091 51413
VOLUME /config /downloads

ENTRYPOINT ["/entrypoint"]
CMD ["-h"]