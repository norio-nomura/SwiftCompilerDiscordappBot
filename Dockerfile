ARG DOCKER_IMAGE
FROM ${DOCKER_IMAGE}
RUN apt-get update && apt-get install -y \
    libsodium-dev libunwind8 && \
    rm -r /var/lib/apt/lists/* && \
    useradd -m swiftbot
ENV RXSWIFT_VERSION=4.1.2
RUN mkdir /RxSwift && cd /RxSwift && \
    curl -L https://github.com/ReactiveX/RxSwift/archive/$RXSWIFT_VERSION.tar.gz | tar zx --strip-components 1 && \
    swift build --target RxSwift -Xswiftc -emit-library -Xswiftc -o -Xswiftc `swift build --show-bin-path`/libRxSwift.so && \
    chmod -R go+rx .build
ADD . /SwiftCompilerDiscordappBot
RUN cd /SwiftCompilerDiscordappBot && \
    SWIFTPM_FLAGS="--configuration release --static-swift-stdlib" && \
    swift build $SWIFTPM_FLAGS && \
    mv `swift build $SWIFTPM_FLAGS --show-bin-path`/SwiftCompilerDiscordappBot /usr/bin && \
    cd / && \
    rm -rf SwiftCompilerDiscordappBot

USER swiftbot
CMD ["SwiftCompilerDiscordappBot"]
