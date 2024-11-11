FROM konflux-ci/bazel-builder/bazel5-ubi8:latest
RUN dnf -y install gcc-c++ git
COPY source source
WORKDIR source
RUN bazel build //main:hello-world
