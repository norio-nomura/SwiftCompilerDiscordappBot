ARG DOCKER_IMAGE
FROM ${DOCKER_IMAGE}
RUN apt-get update && apt-get install -y \
    libsodium-dev libunwind8 && \
    rm -r /var/lib/apt/lists/* && \
    useradd -m swiftbot

ADD Libraries /Libraries
RUN chown -R swiftbot /Libraries
USER swiftbot
RUN cd /Libraries && \
    swift build && \
    chmod -R go+rx .build || true

USER root
ADD . /SwiftCompilerDiscordappBot
RUN cd /SwiftCompilerDiscordappBot && \
    SWIFTPM_FLAGS="--configuration release --static-swift-stdlib" && \
    swift build $SWIFTPM_FLAGS && \
    mv `swift build $SWIFTPM_FLAGS --show-bin-path`/SwiftCompilerDiscordappBot /usr/bin && \
    cd / && \
    rm -rf SwiftCompilerDiscordappBot

USER swiftbot
CMD ["SwiftCompilerDiscordappBot"]
