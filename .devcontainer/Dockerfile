FROM ubuntu:24.04@sha256:52df9b1ee71626e0088f7d400d5c6b5f7bb916f8f0c82b474289a4ece6cf3faf

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY tools/versions.env /tmp/versions.env
COPY .tflint.hcl /tmp/tflint.hcl

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install --yes --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      make \
      python3 \
      python3-venv \
      tar \
      unzip; \
    rm -rf /var/lib/apt/lists/*; \
    test "$(dpkg --print-architecture)" = amd64; \
    source /tmp/versions.env; \
    test "$(python3 --version | awk '{print $2}')" = "$PYTHON_VERSION"; \
    download_verified() { \
      local url=$1 expected=$2 destination=$3; \
      curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
        --output "$destination" "$url"; \
      printf '%s  %s\n' "$expected" "$destination" | sha256sum --check --status; \
    }; \
    tmp_dir=$(mktemp -d); \
    download_verified \
      "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz" \
      "$NODE_LINUX_AMD64_SHA256" \
      "$tmp_dir/node.tar.gz"; \
    tar -xzf "$tmp_dir/node.tar.gz" -C "$tmp_dir"; \
    cp -a "$tmp_dir/node-v${NODE_VERSION}-linux-x64" "/usr/local/lib/node-v${NODE_VERSION}"; \
    ln -s "/usr/local/lib/node-v${NODE_VERSION}/bin/node" /usr/local/bin/node; \
    ln -s "/usr/local/lib/node-v${NODE_VERSION}/lib/node_modules/npm/bin/npm-cli.js" /usr/local/bin/npm; \
    ln -s "/usr/local/lib/node-v${NODE_VERSION}/lib/node_modules/npm/bin/npx-cli.js" /usr/local/bin/npx; \
    download_verified \
      "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
      "$TERRAFORM_LINUX_AMD64_SHA256" \
      "$tmp_dir/terraform.zip"; \
    unzip -q "$tmp_dir/terraform.zip" -d "$tmp_dir/terraform"; \
    install -m 0755 "$tmp_dir/terraform/terraform" /usr/local/bin/terraform; \
    download_verified \
      "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip" \
      "$TFLINT_LINUX_AMD64_SHA256" \
      "$tmp_dir/tflint.zip"; \
    unzip -q "$tmp_dir/tflint.zip" -d "$tmp_dir/tflint"; \
    install -m 0755 "$tmp_dir/tflint/tflint" /usr/local/bin/tflint; \
    download_verified \
      "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
      "$HELM_LINUX_AMD64_SHA256" \
      "$tmp_dir/helm.tar.gz"; \
    tar -xzf "$tmp_dir/helm.tar.gz" -C "$tmp_dir"; \
    install -m 0755 "$tmp_dir/linux-amd64/helm" /usr/local/bin/helm; \
    download_verified \
      "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
      "$KUBECTL_LINUX_AMD64_SHA256" \
      /usr/local/bin/kubectl; \
    chmod 0755 /usr/local/bin/kubectl; \
    download_verified \
      "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
      "$KUBECONFORM_LINUX_AMD64_SHA256" \
      "$tmp_dir/kubeconform.tar.gz"; \
    tar -xzf "$tmp_dir/kubeconform.tar.gz" -C "$tmp_dir"; \
    install -m 0755 "$tmp_dir/kubeconform" /usr/local/bin/kubeconform; \
    download_verified \
      "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64" \
      "$JQ_LINUX_AMD64_SHA256" \
      /usr/local/bin/jq; \
    chmod 0755 /usr/local/bin/jq; \
    npm install --global --prefix /usr/local "markdownlint-cli@${MARKDOWNLINT_VERSION}"; \
    git clone --filter=blob:none --branch "v${BATS_VERSION}" --depth 1 \
      https://github.com/bats-core/bats-core.git "$tmp_dir/bats"; \
    test "$(git -C "$tmp_dir/bats" rev-parse HEAD)" = "$BATS_COMMIT"; \
    "$tmp_dir/bats/install.sh" /usr/local; \
    rm -rf "$tmp_dir"; \
    id ubuntu; \
    mkdir -p /workspace; \
    chown ubuntu:ubuntu /workspace

USER ubuntu
WORKDIR /workspace
ENV PATH="/workspace/.venv/bin:/home/ubuntu/.local/bin:/usr/local/bin:${PATH}"

RUN tflint --config=/tmp/tflint.hcl --init

CMD ["sleep", "infinity"]
