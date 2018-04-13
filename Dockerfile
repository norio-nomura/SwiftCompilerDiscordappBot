ARG DOCKER_IMAGE
FROM ${DOCKER_IMAGE}
RUN apt-get update && apt-get install -y \
    libsodium-dev && \
    rm -r /var/lib/apt/lists/* && \
    useradd -m swiftbot
ADD . /SwiftCompilerDiscordappBot
RUN cd /SwiftCompilerDiscordappBot && \
    swift build --configuration release --static-swift-stdlib && \
    mv `swift build --configuration release --static-swift-stdlib --show-bin-path`/SwiftCompilerDiscordappBot /usr/bin && \
    cd / && \
    rm -rf SwiftCompilerDiscordappBot

USER swiftbot
CMD ["SwiftCompilerDiscordappBot"]
