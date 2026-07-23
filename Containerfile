
ARG IMAGE
FROM $IMAGE as builder

ARG BAZEL_VERSION
ARG OPENJDK_VERSION
ARG UBI_VERSION

# install dependencies
RUN test "$UBI_VERSION" = "8" && dnf -y install gcc-c++ zip unzip java-"$OPENJDK_VERSION"-openjdk-devel python39 gpg || true
RUN test "$UBI_VERSION" = "9" && dnf -y install gcc-c++ zip unzip java-"$OPENJDK_VERSION"-openjdk-devel python3 gpg || true

# fetch source
# RUN curl -LO https://github.com/bazelbuild/bazel/releases/download/"$BAZEL_VERSION"/bazel-"$BAZEL_VERSION"-dist.zip
# COPY ./cachi2/output/deps/generic/bazel-"$BAZEL_VERSION"-dist.zip bazel-"$BAZEL_VERSION"-dist.zip

# verify signature
# RUN curl -LO https://github.com/bazelbuild/bazel/releases/download/"$BAZEL_VERSION"/bazel-"$BAZEL_VERSION"-dist.zip.sig
COPY bazel-release.pub.gpg bazel-release.pub.gpg
RUN gpg --import bazel-release.pub.gpg
RUN gpg --verify ./cachi2/output/deps/generic/bazel-$BAZEL_VERSION-dist.zip.sig  ./cachi2/output/deps/generic/bazel-"$BAZEL_VERSION"-dist.zip

# build
RUN unzip ./cachi2/output/deps/generic/bazel-"$BAZEL_VERSION"-dist.zip -d /bazel
WORKDIR /bazel
# workaround for ppc64le: linux_ppc64le config_setting in Bazel's src/conditions/BUILD{,.tools}
# incorrectly uses @platforms//cpu:ppc instead of @platforms//cpu:ppc64le, causing rules_java
# to not find jni_md.h (https://github.com/bazelbuild/bazel/issues/11754)
RUN if [ "$(uname -m)" = "ppc64le" ]; then \
      sed -i '/name = "linux_ppc64le"/,/\]/{s|"@platforms//cpu:ppc"|"@platforms//cpu:ppc64le"|}' \
        src/conditions/BUILD src/conditions/BUILD.tools ; \
    fi
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

LABEL \
  description="Konflux image containing rebuilds for tooling to assist in building with bazel." \
  io.k8s.description="Konflux image containing rebuilds for tooling to assist in building with bazel." \
  summary="Konflux bazel builder" \
  io.k8s.display-name="Konflux bazel builder" \
  io.openshift.tags="konflux build bazel tekton pipeline security" \
  name="Konflux bazel builder" \
  com.redhat.component="bazel-builder"
