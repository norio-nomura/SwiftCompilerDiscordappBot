ARG DOCKER_IMAGE=norionomura/swift:5.0
FROM norionomura/swift:5.0 as builder
RUN apt-get update && apt-get install -y \
    libsodium-dev libunwind8 libssl-dev && \
    rm -r /var/lib/apt/lists/* && \
    useradd -m swiftbot

RUN mkdir -p /SwiftCompilerDiscordappBot/Sources/SwiftCompilerDiscordappBot
ADD Package.* /SwiftCompilerDiscordappBot/
ADD Sources /SwiftCompilerDiscordappBot/Sources/
RUN cd /SwiftCompilerDiscordappBot && \
    SWIFTPM_FLAGS="--configuration release --static-swift-stdlib" && \
    swift build $SWIFTPM_FLAGS && \
    mv `swift build $SWIFTPM_FLAGS --show-bin-path`/SwiftCompilerDiscordappBot /usr/bin && \
    cd / && \
    rm -rf SwiftCompilerDiscordappBot

FROM ${DOCKER_IMAGE}
RUN apt-get update && apt-get install -y \
    libsodium-dev libunwind8 libssl1.0.0 && \
    rm -r /var/lib/apt/lists/* && \
    useradd -m swiftbot

COPY --from=builder /usr/bin/SwiftCompilerDiscordappBot /usr/bin
RUN mkdir -p /swiftbot/lib
COPY --from=builder /usr/lib/swift/linux/libBlocksRuntime.so /swiftbot/lib
COPY --from=builder /usr/lib/swift/linux/libdispatch.so /swiftbot/lib
COPY --from=builder /usr/lib/swift/linux/libFoundation.so /swiftbot/lib
COPY --from=builder /usr/lib/swift/linux/libicudataswift.so.61 /swiftbot/lib
COPY --from=builder /usr/lib/swift/linux/libicui18nswift.so.61 /swiftbot/lib
COPY --from=builder /usr/lib/swift/linux/libicuucswift.so.61 /swiftbot/lib
COPY --from=builder /usr/lib/swift/linux/libswiftCore.so /swiftbot/lib
COPY --from=builder /usr/lib/swift/linux/libswiftDispatch.so /swiftbot/lib
COPY --from=builder /usr/lib/swift/linux/libswiftGlibc.so /swiftbot/lib

USER swiftbot
ENV LD_LIBRARY_PATH=/swiftbot/lib
CMD ["SwiftCompilerDiscordappBot"]
