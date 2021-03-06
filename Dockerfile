# builder image (build tools + development dependencies):
FROM debian:buster as builder
ARG BUILD_TYPE=Debug
ARG MONGODB_SUPPORT=ON
RUN apt update && \
    apt install -y build-essential git clang-tidy cmake pkg-config libczmq-dev libpfm4-dev libsystemd-dev uuid-dev && \
    echo "${MONGODB_SUPPORT}" |grep -iq "on" && apt install -y libmongoc-dev || true
COPY . /usr/src/hwpc-sensor
RUN cd /usr/src/hwpc-sensor && \
    mkdir build && \
    cd build && \
    GIT_TAG=$(git describe --tags --dirty 2>/dev/null || echo "unknown") \
    GIT_REV=$(git rev-parse HEAD 2>/dev/null || echo "unknown") \
    cmake -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DCMAKE_C_CLANG_TIDY="clang-tidy" -DWITH_MONGODB="${MONGODB_SUPPORT}" .. && \
    make -j $(getconf _NPROCESSORS_ONLN)

# runner image (only runtime depedencies):
FROM debian:buster as runner
ARG BUILD_TYPE=Debug
ARG MONGODB_SUPPORT=ON
RUN apt update && \
    apt install -y libczmq4 libpfm4 && \
    echo "${MONGODB_SUPPORT}" |grep -iq "on" && apt install -y libmongoc-1.0-0 || true && \
    echo "${BUILD_TYPE}" |grep -iq "debug" && apt install -y libasan5 libubsan1 || true && \
    rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/src/hwpc-sensor/build/hwpc-sensor /usr/bin/hwpc-sensor
ENTRYPOINT ["/usr/bin/hwpc-sensor"]
CMD ["--help"]
