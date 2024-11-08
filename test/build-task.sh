#!/bin/bash
set -e

SOURCE_CODE_DIR="/source"
DOCKERFILE="Dockerfile"
HERMETIC="true"
CONTEXT=""
TLSVERIFY="true"

ca_bundle=/mnt/trusted-ca/ca-bundle.crt
if [ -f "$ca_bundle" ]; then
  echo "INFO: Using mounted CA bundle: $ca_bundle"
  cp -vf $ca_bundle /etc/pki/ca-trust/source/anchors
  update-ca-trust
fi

dockerfile_path="$SOURCE_CODE_DIR/$DOCKERFILE"

# #SOURCE_CODE_DIR=source
# if [ -e "$SOURCE_CODE_DIR/$CONTEXT/$DOCKERFILE" ]; then
#   dockerfile_path="$(pwd)/$SOURCE_CODE_DIR/$CONTEXT/$DOCKERFILE"
# elif [ -e "$SOURCE_CODE_DIR/$DOCKERFILE" ]; then
#   dockerfile_path="$(pwd)/$SOURCE_CODE_DIR/$DOCKERFILE"
# elif echo "$DOCKERFILE" | grep -q "^https\?://"; then
#   echo "Fetch Dockerfile from $DOCKERFILE"
#   dockerfile_path=$(mktemp --suffix=-Dockerfile)
#   http_code=$(curl -s -L -w "%{http_code}" --output "$dockerfile_path" "$DOCKERFILE")
#   if [ $http_code != 200 ]; then
#     echo "No Dockerfile is fetched. Server responds $http_code"
#     exit 1
#   fi
#   http_code=$(curl -s -L -w "%{http_code}" --output "$dockerfile_path.dockerignore.tmp" "$DOCKERFILE.dockerignore")
#   if [ $http_code = 200 ]; then
#     echo "Fetched .dockerignore from $DOCKERFILE.dockerignore"
#     mv "$dockerfile_path.dockerignore.tmp" $SOURCE_CODE_DIR/$CONTEXT/.dockerignore
#   fi
# else
#   echo "Cannot find Dockerfile $DOCKERFILE"
#   exit 1
# fi
# if [ -n "$JVM_BUILD_WORKSPACE_ARTIFACT_CACHE_PORT_80_TCP_ADDR" ] && grep -q '^\s*RUN \(./\)\?mvn' "$dockerfile_path"; then
#   sed -i -e "s|^\s*RUN \(\(./\)\?mvn\)\(.*\)|RUN echo \"<settings><mirrors><mirror><id>mirror.default</id><url>http://$JVM_BUILD_WORKSPACE_ARTIFACT_CACHE_PORT_80_TCP_ADDR/v1/cache/default/0/</url><mirrorOf>*</mirrorOf></mirror></mirrors></settings>\" > /tmp/settings.yaml; \1 -s /tmp/settings.yaml \3|g" "$dockerfile_path"
#   touch /var/lib/containers/java
# fi

# Fixing group permission on /var/lib/containers
chown root:root /var/lib/containers

sed -i 's/^\s*short-name-mode\s*=\s*.*/short-name-mode = "disabled"/' /etc/containers/registries.conf

# Setting new namespace to run buildah - 2^32-2
echo 'root:1:4294967294' | tee -a /etc/subuid >> /etc/subgid

build_args=()
if [ -n "${BUILD_ARGS_FILE}" ]; then
  # Parse BUILD_ARGS_FILE ourselves because dockerfile-json doesn't support it
  echo "Parsing ARGs from $BUILD_ARGS_FILE"
  mapfile -t build_args < <(
    # https://www.mankier.com/1/buildah-build#--build-arg-file
    # delete lines that start with #
    # delete blank lines
    sed -e '/^#/d' -e '/^\s*$/d' "${SOURCE_CODE_DIR}/${BUILD_ARGS_FILE}"
  )
fi
# Append BUILD_ARGS
# Note: this may result in multiple --build-arg=KEY=value flags with the same KEY being
# passed to buildah. In that case, the *last* occurrence takes precedence. This is why
# we append BUILD_ARGS after the content of the BUILD_ARGS_FILE - they take precedence.
build_args+=("$@")

BUILD_ARG_FLAGS=()
for build_arg in "${build_args[@]}"; do
  BUILD_ARG_FLAGS+=("--build-arg=$build_arg")
done

BASE_IMAGES=$(
  dockerfile-json "${BUILD_ARG_FLAGS[@]}" "$dockerfile_path" |
    jq -r '.Stages[] | select(.From | .Stage or .Scratch | not) | .BaseName | select(test("^oci-archive:") | not)'
)

BUILDAH_ARGS=()

if [ "${HERMETIC}" == "true" ]; then
  BUILDAH_ARGS+=("--pull=never")
  UNSHARE_ARGS="--net"
  for image in $BASE_IMAGES; do
    unshare -Ufp --keep-caps -r --map-users 1,1,65536 --map-groups 1,1,65536 -- buildah pull $image
  done
  echo "Build will be executed with network isolation"
fi

if [ -n "${TARGET_STAGE}" ]; then
  BUILDAH_ARGS+=("--target=${TARGET_STAGE}")
fi

BUILDAH_ARGS+=("${BUILD_ARG_FLAGS[@]}")

if [ -n "${ADD_CAPABILITIES}" ]; then
  BUILDAH_ARGS+=("--cap-add=${ADD_CAPABILITIES}")
fi

if [ "${SQUASH}" == "true" ]; then
  BUILDAH_ARGS+=("--squash")
fi

if [ "${SKIP_UNUSED_STAGES}" != "true" ] ; then
  BUILDAH_ARGS+=("--skip-unused-stages=false")
fi

# if [ -f "$(workspaces.source.path)/cachi2/cachi2.env" ]; then
#   cp -r "$(workspaces.source.path)/cachi2" /tmp/
#   chmod -R go+rwX /tmp/cachi2
#   VOLUME_MOUNTS="--volume /tmp/cachi2:/cachi2"
#   # Read in the whole file (https://unix.stackexchange.com/questions/533277), then
#   # for each RUN ... line insert the cachi2.env command *after* any options like --mount
#   sed -E -i \
#       -e 'H;1h;$!d;x' \
#       -e 's@^\s*(run((\s|\\\n)+-\S+)*(\s|\\\n)+)@\1. /cachi2/cachi2.env \&\& \\\n    @igM' \
#       "$dockerfile_path"
#   echo "Prefetched content will be made available"

#   prefetched_repo_for_my_arch="/tmp/cachi2/output/deps/rpm/$(uname -m)/repos.d/cachi2.repo"
#   if [ -f "$prefetched_repo_for_my_arch" ]; then
#     echo "Adding $prefetched_repo_for_my_arch to $YUM_REPOS_D_FETCHED"
#     mkdir -p "$YUM_REPOS_D_FETCHED"
#     cp --no-clobber "$prefetched_repo_for_my_arch" "$YUM_REPOS_D_FETCHED"
#   fi
# fi

# if yum repofiles stored in git, copy them to mount point outside the source dir
# if [ -d "${SOURCE_CODE_DIR}/${YUM_REPOS_D_SRC}" ]; then
#   mkdir -p ${YUM_REPOS_D_FETCHED}
#   cp -r ${SOURCE_CODE_DIR}/${YUM_REPOS_D_SRC}/* ${YUM_REPOS_D_FETCHED}
# fi

# # if anything in the repofiles mount point (either fetched or from git), mount it
# if [ -d "${YUM_REPOS_D_FETCHED}" ]; then
#   chmod -R go+rwX ${YUM_REPOS_D_FETCHED}
#   mount_point=$(realpath ${YUM_REPOS_D_FETCHED})
#   VOLUME_MOUNTS="${VOLUME_MOUNTS} --volume ${mount_point}:${YUM_REPOS_D_TARGET}"
# fi

LABELS=(
  "--label" "build-date=$(date -u +'%Y-%m-%dT%H:%M:%S')"
  "--label" "architecture=$(uname -m)"
  "--label" "vcs-type=git"
)
[ -n "$COMMIT_SHA" ] && LABELS+=("--label" "vcs-ref=$COMMIT_SHA")
[ -n "$IMAGE_EXPIRES_AFTER" ] && LABELS+=("--label" "quay.expires-after=$IMAGE_EXPIRES_AFTER")

# ACTIVATION_KEY_PATH="/activation-key"
# ENTITLEMENT_PATH="/entitlement"

# # do not enable activation key and entitlement at same time. If both vars are provided, prefer activation key.
# # when activation keys are used an empty directory on shared emptydir volume to "/etc/pki/entitlement" to prevent certificates from being included in the produced container
# # To use activation key file 'org' must exist, which means the key 'org' must exist in the key/value secret

# if [ -e /activation-key/org ]; then
#   cp -r --preserve=mode "$ACTIVATION_KEY_PATH" /tmp/activation-key
#   mkdir /shared/rhsm-tmp
#   VOLUME_MOUNTS="${VOLUME_MOUNTS} --volume /tmp/activation-key:/activation-key -v /shared/rhsm-tmp:/etc/pki/entitlement:Z"
#   echo "Adding activation key to the build"

# elif find /entitlement -name "*.pem" >> null; then
#   cp -r --preserve=mode "$ENTITLEMENT_PATH" /tmp/entitlement
#   VOLUME_MOUNTS="${VOLUME_MOUNTS} --volume /tmp/entitlement:/etc/pki/entitlement"
#   echo "Adding the entitlement to the build"
# fi

# ADDITIONAL_SECRET_PATH="/additional-secret"
# ADDITIONAL_SECRET_TMP="/tmp/additional-secret"
# if [ -d "$ADDITIONAL_SECRET_PATH" ]; then
#   cp -r --preserve=mode -L "$ADDITIONAL_SECRET_PATH" $ADDITIONAL_SECRET_TMP
#   while read -r filename; do
#     echo "Adding the secret ${ADDITIONAL_SECRET}/${filename} to the build, available at /run/secrets/${ADDITIONAL_SECRET}/${filename}"
#     BUILDAH_ARGS+=("--secret=id=${ADDITIONAL_SECRET}/${filename},src=$ADDITIONAL_SECRET_TMP/${filename}")
#   done < <(find $ADDITIONAL_SECRET_TMP -maxdepth 1 -type f -exec basename {} \;)
# fi

buildah_cmd_array=(
        buildah build
        # "${VOLUME_MOUNTS[@]}"
        "${BUILDAH_ARGS[@]}"
        "${LABELS[@]}"
        --tls-verify="$TLSVERIFY" --no-cache
        --ulimit nofile=4096:4096
        --storage-driver=vfs
        -f "$dockerfile_copy" -t "$IMAGE" .
      )
      buildah_cmd=$(printf "%q " "${buildah_cmd_array[@]}")

      if [ "${HERMETIC}" == "true" ]; then
        # enabling loopback adapter enables Bazel builds to work in hermetic mode.
        command="ip link set lo up && $buildah_cmd"
      else
        command="$buildah_cmd"
      fi

 unshare -Uf "${UNSHARE_ARGS[@]}" --keep-caps -r --map-users 1,1,65536 --map-groups 1,1,65536 -w "${SOURCE_CODE_DIR}/$CONTEXT" -- sh -c "$command"

# unshare -Uf $UNSHARE_ARGS --keep-caps -r --map-users 1,1,65536 --map-groups 1,1,65536 -w ${SOURCE_CODE_DIR}/$CONTEXT -- buildah build \
#   #$VOLUME_MOUNTS \
#   "${BUILDAH_ARGS[@]}" \
#   "${LABELS[@]}" \
#   --tls-verify=$TLSVERIFY --no-cache \
#   --ulimit nofile=4096:4096 \
#   -f "$dockerfile_path" -t $IMAGE .
