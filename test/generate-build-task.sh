tkn bundle list -o yaml quay.io/konflux-ci/tekton-catalog/task-buildah:0.2 > buildah-build-task.yaml

yq -i 'del(.spec.steps[] | select(.name == "sbom-syft-generate"))' buildah-build-task.yaml
yq -i 'del(.spec.steps[] | select(.name == "analyse-dependencies-java-sbom"))' buildah-build-task.yaml
yq -i 'del(.spec.steps[] | select(.name == "prepare-sboms"))' buildah-build-task.yaml
yq -i 'del(.spec.steps[] | select(.name == "inject-sbom-and-push"))' buildah-build-task.yaml
yq -i 'del(.spec.steps[] | select(.name == "upload-sbom"))' buildah-build-task.yaml
