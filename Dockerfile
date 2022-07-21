FROM registry.fedoraproject.org/fedora-toolbox:36
LABEL summary="Base image for feadora toolbox" \
      maintainer="Felix Proehl <felix@golane.de>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install additional modules.
RUN dnf module -y install nodejs:16/development &&\
    dnf clean all

# Add thirdparty repos.
RUN dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo &&\
    dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo

# Install fusion repos.
ARG FEDORA_VERSION=36
RUN dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm"\
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm" &&\
    dnf clean all

# Install additional requirements.
# hadolint ignore=DL3041
RUN dnf install -y chromium docker-ce-cli docker-compose gh google-noto-emoji-color-fonts java java-11-openjdk-devel\
    jq libvirt-client libXScrnSaver make openssl podman-remote akmod-nvidia ImageMagick mesa-dri-drivers ruby-devel\
    gcc gcc-c++ clang-tools-extra cmake protobuf-compiler protobuf-devel upx &&\
    dnf clean all
ENV DOCKER_HOST="unix:///run/user/1000/podman/podman.sock"
ENV CHROME_EXECUTABLE="/usr/bin/chromium-browser"

# Install golang
# renovate: datasource=git-tags depName=https://github.com/golang/go.git
ARG GO_VERSION=1.18.4
RUN curl -Lo go.linux-amd64.tar.gz "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" &&\
    rm -rf /usr/local/go && tar -C /usr/local -xzf go.linux-amd64.tar.gz &&\
    rm -f go.linux-amd64.tar.gz
ENV PATH="$PATH:/usr/local/go/bin:${HOME_PATH}/go/bin"
ENV GOPRIVATE=github.com/bluegosolutions

# Install go packages
# renovate: datasource=github-tags depName=mikefarah/yq
ARG YQ_VERSION=4.26.1
# renovate: datasource=git-tags depName=https://github.com/golang/tools.git
ARG GOIMPORTS_VERSION=0.1.11
# renovate: datasource=git-tags depName=https://github.com/grpc/grpc-go.git
ARG PROTOC_GEN_GO_GRPC_VERSION=1.2.0
RUN for p in "github.com/mikefarah/yq/v4@v${YQ_VERSION}" "golang.org/x/tools/cmd/goimports@v${GOIMPORTS_VERSION}"\
    "google.golang.org/grpc/cmd/protoc-gen-go-grpc@v${PROTOC_GEN_GO_GRPC_VERSION}" ; do go install "$p" ; done

# Install AWS CLI.
# renovate: datasource=git-tags depName=https://github.com/aws/aws-cli.git
ARG AWS_CLI_VERSION=2.7.17
RUN curl -o "/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" &&\
    unzip -q "/awscliv2.zip" &&\
    ./aws/install &&\
    rm -rf "/awscliv2.zip" /aws

# Install kubectl
# renovate: datasource=github-tags depName=kubernetes/kubectl
ARG KUBECTL_VERSION=1.24.3
RUN curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" &&\
    curl -LO "https://dl.k8s.io/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" &&\
    echo "$(<kubectl.sha256) kubectl" | sha256sum --check &&\
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl &&\
    echo 'source <(kubectl completion bash)' > /etc/profile.d/kubectl.sh &&\
    rm -rf kubectl kubectl.sha256

# Install minikube
# renovate: datasource=github-tags depName=kubernetes/minikube
ARG MINIKUBE_VERSION=1.26.0
RUN curl -LO "https://storage.googleapis.com/minikube/releases/v${MINIKUBE_VERSION}/minikube-${MINIKUBE_VERSION}-0.x86_64.rpm" &&\
    rpm -ivh "minikube-${MINIKUBE_VERSION}-0.x86_64.rpm" &&\
    rm -rf "minikube-${MINIKUBE_VERSION}-0.x86_64.rpm"

# Install helm
# renovate: datasource=git-tags depName=https://github.com/helm/helm.git
ARG HELM_VERSION=3.9.2
RUN curl -LO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" &&\
    curl -LO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum" &&\
    sha256sum -c "helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum" &&\
    tar -zxvf "helm-v${HELM_VERSION}-linux-amd64.tar.gz" -C ./usr/local/bin --no-anchored --strip-components 1 helm &&\
    rm -f "helm-v${HELM_VERSION}-linux-amd64.tar.gz" "helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum"

# Install helm plugins
# renovate: datasource=github-tags depName=databus23/helm-diff
ARG HELM_DIFF_VERSION=3.5.0
# renovate: datasource=github-tags depName=aslafy-z/helm-git
ARG HELM_GIT_VERSION=0.11.2
RUN helm plugin install https://github.com/databus23/helm-diff --version "${HELM_DIFF_VERSION}" &&\
    helm plugin install https://github.com/aslafy-z/helm-git --version "${HELM_GIT_VERSION}"

# Install trivy && install dockle
# renovate: datasource=github-tags depName=aquasecurity/trivy
ARG TRIVY_VERSION=0.30.1
# renovate: datasource=github-tags depName=goodwithtech/dockle
ARG DOCKLE_VERSION=0.4.5
RUN rpm -ivh "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.rpm" &&\
    rpm -ivh "https://github.com/goodwithtech/dockle/releases/download/v${DOCKLE_VERSION}/dockle_${DOCKLE_VERSION}_Linux-64bit.rpm"

# Install hadolint
# renovate: datasource=github-tags depName=hadolint/hadolint
ARG HADOLINT_VERSION=2.10.0
RUN curl -qLo /usr/local/bin/hadolint "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64" &&\
    chmod +x /usr/local/bin/hadolint

#### Install Android and Flutter ####
ENV HOME_DIR="/var/lib/developer"
RUN useradd -u 1000 -U -d ${HOME_DIR} developer
USER developer

# Install Android SDK and tools.
ENV ANDROID_SDK_ROOT="${HOME_DIR}/android/sdk"
ENV ANDROID_SDK_MANAGER="${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager"
ENV PATH=${PATH}:${ANDROID_SDK_ROOT}/tools:${ANDROID_SDK_ROOT}/platform-tools
RUN curl -L -o "${HOME_DIR}/android-cmdline-tools.zip" https://dl.google.com/android/repository/commandlinetools-linux-6858069_latest.zip &&\
    install -d "${ANDROID_SDK_ROOT}" &&\
    unzip -q "${HOME_DIR}/android-cmdline-tools.zip" -d "${ANDROID_SDK_ROOT}" &&\
    rm -rf "${HOME_DIR}/android-cmdline-tools.zip" &&\
    yes | "${ANDROID_SDK_MANAGER}" --sdk_root="${ANDROID_SDK_ROOT}" --licenses || true &&\
    yes | "${ANDROID_SDK_MANAGER}" --sdk_root="${ANDROID_SDK_ROOT}" emulator || true &&\
    "${ANDROID_SDK_MANAGER}" --sdk_root="${ANDROID_SDK_ROOT}" "build-tools;29.0.3" "cmdline-tools;latest"\
    "patcher;v4" "platforms;android-31" "platform-tools" "sources;android-31"

# Install Flutter SDK and setup.
# renovate: datasource=git-tags depName=https://github.com/flutter/flutter.git
ARG FLUTTER_VERSION=3.0.5
ARG FLUTTER_CHANNEL="stable"
ENV FLUTTER_SDK_ROOT="${HOME_DIR}/flutter"
ENV PATH=${PATH}:${FLUTTER_SDK_ROOT}/bin
RUN curl -L -o "${HOME_DIR}/flutter.tar.xz" "https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz" &&\
    tar -xf "${HOME_DIR}/flutter.tar.xz" -C "$(dirname ${FLUTTER_SDK_ROOT})" &&\
    rm -rf "${HOME_DIR}/flutter.tar.xz" &&\
    flutter config --enable-web &&\
    flutter doctor &&\
    rm -rf /var/lib/developer/flutter/bin/cache

# hadolint ignore=DL3002
USER root
RUN userdel developer

#### END: Install Android and Flutter ####

# Install bundler (required for fastlane)
# renovate: datasource=rubygems depName=bundler
ARG BUNDLER_VERSION=2.3.18
RUN gem install "bundler:${BUNDLER_VERSION}"

# Install Gradle
# renovate: datasource=github-tags depName=gradle/gradle
ARG GRADLE_VERSION=7.5.0
RUN curl -L -o /tmp/gradle.zip "https://services.gradle.org/distributions/gradle-$(sed -e 's/.0$//' <<< "${GRADLE_VERSION}")-bin.zip" &&\
    mkdir /opt/gradle &&\
    unzip -qd /opt/gradle /tmp/gradle.zip &&\
    rm -f /tmp/gradle.zip
ENV PATH="${PATH}:/opt/gradle/bin"

RUN rm -rf /tmp/*
