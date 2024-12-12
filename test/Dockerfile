ARG FROM
FROM $FROM

RUN dnf -y install gcc-c++ git
COPY source /source
WORKDIR /source

# This will be run in the test pipeline.
RUN bazel build //main:hello-world
