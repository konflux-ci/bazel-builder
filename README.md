# bazel-builder

This repository contains recipes to build OCI builder images that provide Bazel built *entirely from source*, not installed via Bazelisk or built using another pre-compiled Bazel binary. The builds themselves are run on [Konflux-CI](https://konflux-ci.dev/) using [Hermeto](https://github.com/hermetoproject/hermeto) and are accompanied by detailed provenance and sboms.

The image builds themselves are maintained in branches (bazel5-ubi8, bazel6-ubi9) to better facilitate automated dependency updates with Renovate.

Currently there are builder for bazel 5 and 6 available with more coming soon.  

Images are published to:  

* [quay.io/konflux-ci/bazel5-ubi8](https://quay.io/repository/konflux-ci/bazel5-ubi8)
* [quay.io/konflux-ci/bazel6-ubi9](https://quay.io/repository/konflux-ci/bazel6-ubi9)

