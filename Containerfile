ARG IMAGE
FROM $IMAGE as builder

ARG BAZEL_VERSION
ARG OPENJDK_VERSION
ARG UBI_VERSION

# install dependencies
RUN test "$UBI_VERSION" = "8" && dnf -y install gcc-c++ zip unzip java-"$OPENJDK_VERSION"-openjdk-devel python39 gpg || true
RUN test "$UBI_VERSION" = "9" && dnf -y install gcc-c++ zip unzip java-"$OPENJDK_VERSION"-openjdk-devel python3 gpg || true

## used for local build only
#RUN curl -LO https://github.com/bazelbuild/bazel/releases/download/"$BAZEL_VERSION"/bazel-"$BAZEL_VERSION"-dist.zip
#RUN unzip ./bazel-"$BAZEL_VERSION"-dist.zip -d /bazel

COPY bazel-release.pub.gpg bazel-release.pub.gpg
RUN gpg --import bazel-release.pub.gpg
RUN gpg --verify ./cachi2/output/deps/generic/bazel-$BAZEL_VERSION-dist.zip.sig  ./cachi2/output/deps/generic/bazel-"$BAZEL_VERSION"-dist.zip

# build
RUN unzip ./cachi2/output/deps/generic/bazel-"$BAZEL_VERSION"-dist.zip -d /bazel
WORKDIR /bazel
# workaround for https://github.com/bazelbuild/bazel/issues/27401
RUN env BAZEL_DEV_VERSION_OVERRIDE=7.7.1 EXTRA_BAZEL_ARGS="--tool_java_runtime_version=local_jdk --lockfile_mode=off" bash ./compile.sh
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

LABEL \
  description="Konflux image containing rebuilds for tooling to assist in building with bazel." \
  io.k8s.description="Konflux image containing rebuilds for tooling to assist in building with bazel." \
  summary="Konflux bazel builder" \
  io.k8s.display-name="Konflux bazel builder" \
  io.openshift.tags="konflux build bazel tekton pipeline security" \
  name="Konflux bazel builder" \
  com.redhat.component="bazel-builder"
