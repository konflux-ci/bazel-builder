
ARG IMAGE
FROM $IMAGE as builder

# temporary
RUN ls -alR ./cachi2/output/deps/generic

ARG BAZEL_VERSION
ARG OPENJDK_VERSION
ARG UBI_VERSION

# install dependencies
RUN test "$UBI_VERSION" = "8" && dnf -y install gcc-c++ zip unzip java-"$OPENJDK_VERSION"-openjdk-devel python39 gpg || true
RUN test "$UBI_VERSION" = "9" && dnf -y install gcc-c++ zip unzip java-"$OPENJDK_VERSION"-openjdk-devel python3 gpg || true

# fetch source
# RUN curl -LO https://github.com/bazelbuild/bazel/releases/download/"$BAZEL_VERSION"/bazel-"$BAZEL_VERSION"-dist.zip
COPY ./cachi2/output/deps/"$BAZEL_VERSION"/bazel-"$BAZEL_VERSION"-dist.zip "$BAZEL_VERSION"/bazel-"$BAZEL_VERSION"-dist.zip

# verify signature
RUN curl -LO https://github.com/bazelbuild/bazel/releases/download/"$BAZEL_VERSION"/bazel-"$BAZEL_VERSION"-dist.zip.sig
COPY bazel-release.pub.gpg bazel-release.pub.gpg
RUN gpg --import bazel-release.pub.gpg
RUN gpg --verify /bazel-$BAZEL_VERSION-dist.zip.sig bazel-"$BAZEL_VERSION"-dist.zip

# build
RUN unzip bazel-"$BAZEL_VERSION"-dist.zip -d /bazel
WORKDIR /bazel
RUN  env EXTRA_BAZEL_ARGS="--tool_java_runtime_version=local_jdk" bash ./compile.sh
RUN scripts/generate_bash_completion.sh --bazel=output/bazel --output=output/bazel-complete.bash

# Copy
ARG IMAGE
FROM $IMAGE
ARG BAZEL_VERSION
ARG OPENJDK_VERSION

RUN  dnf -y install java-"$OPENJDK_VERSION"-openjdk-devel
COPY --from=builder /bazel/output/bazel-complete.bash /usr/share/bash-completion/completions/bazel
COPY --from=builder /bazel/output/bazel /usr/bin/bazel-"$BAZEL_VERSION"
COPY --from=builder /bazel/scripts/packages/bazel.sh /usr/bin/bazel
