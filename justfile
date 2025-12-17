# STARDEV - Justfile
# ------------------------------------

# Load environment variables from .env file
set dotenv-path := "./"
set dotenv-load

# List all available commands
default:
    @just --list

[group('Bootstrap')]
bootstrap-gmk:
    #!/usr/bin/env bash
    set -euxo pipefail

    # server setup - disable sleep
    just disable-all-sleep

    # flatpaks
    flatpak install flathub com.google.Chrome -y
    flatpak install flathub org.virt_manager.virt-manager -y

    just uninstall-flatpaks org.pinta_project.Pinta
    just uninstall-flatpaks org.gnome.Thunderbird
    just uninstall-flatpaks org.mozilla.Thunderbird
    just uninstall-flatpaks org.gnome.Weather
    just uninstall-flatpaks org.gnome.DejaDup
    just uninstall-flatpaks io.github.flattool.Warehouse
    just uninstall-flatpaks org.gnome.Calculator

    # brew
    brew install kubectl
    brew install helm
    brew install k9s
    brew install yq
    
    # init pass store
    # just init-pass

[group('Helper Utilities')]
uninstall-flatpaks package:
    #!/usr/bin/env bash
    set -euxo pipefail
    
    if flatpak list | grep -q "{{package}}"; then
        echo "Uninstalling flatpak package: {{package}}"
        flatpak uninstall flathub "{{package}}" -y
    else
        echo "Flatpak package {{package}} is not installed. Skipping uninstallation."
    fi

# Helper to check if a file exists and skip if present, else delete previous versions and download
[group('Helper Utilities')]
download-if-missing url output pattern sbom_name sbom_version quiet="true":
    #!/usr/bin/env bash
    set -euxo pipefail
    if [ -f {{output}} ]; then
      echo "INFO: {{output}} already exists, skipping download."
    else
      # Test for previous versions existing in destination folder
      shopt -s nullglob
      matches=({{pattern}})
      if [[ ${#matches[@]} -eq 0 ]]; then
        echo "INFO: Pattern not matched - {{pattern}}" >&2
      else
        echo "INFO: Pattern matched - ${matches[*]}"
        echo "INFO: Removing previous version(s) matching {{pattern}}"
        rm -f {{pattern}}
      fi
      shopt -u nullglob
      
      # Download via wget
      if [ {{quiet}} = "true" ]; then
        wget -q --tries=5 --timeout=30 {{url}} -O {{output}}
      else
        wget --tries=5 --timeout=30 {{url}} -O {{output}}
      fi
      echo "INFO: Downloaded to {{output}}"
    fi
    
    # Write version to sbom.json
    sh ${SCRIPTS_PATH}/sbom.sh {{sbom_name}} {{sbom_version}} $HOME/sbom.json
    echo "INFO: Successfully written to {{sbom_name}}:{{sbom_version}} sbom.json"

# Helper to download Helm chart from repository using alpine/helm container
[group('Helper Utilities')]
download-helmchart chartName repoUrl outputPath cleanup="true":
    #!/usr/bin/env bash
    set -euxo pipefail

    mkdir -p {{outputPath}}

    helm pull {{chartName}} --repo {{repoUrl}} --destination {{outputPath}}

    echo "INFO: Downloaded {{chartName}} chart to {{outputPath}}"

# Download Talos
[group('Talos')]
download-talos path="${FILES_PATH}/talos" lSchematicId="613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245" lnSchematicId="a7f28b0911f104b421ae99841c58fa52b6694bf960e384442f8746ef792d1f82" architecture="amd64":
    #!/usr/bin/env bash
    set -euxo pipefail

    mkdir -p {{path}}

    # Download talosctl binary if not present, else skip
    just download-if-missing "https://github.com/siderolabs/talos/releases/download/v${TALOS_VERSION}/talosctl-linux-amd64" "{{path}}/talosctl-${TALOS_VERSION}-linux-amd64" "{{path}}/talosctl-*-linux-amd64" talosctl ${TALOS_VERSION} "false"

    # Download talos lh iso if not present, else skip
    just download-if-missing "https://factory.talos.dev/image/{{lSchematicId}}/v${TALOS_VERSION}/metal-amd64.iso" "{{path}}/talos-metal-{{lSchematicId}}-${TALOS_VERSION}-{{architecture}}.iso" "{{path}}/talos-metal-{{lSchematicId}}-*-{{architecture}}.iso" talos-metal-{{architecture}} ${TALOS_VERSION} "false"

    # Download talos lh + nvidia iso if not present, else skip
    just download-if-missing "https://factory.talos.dev/image/{{lnSchematicId}}/v${TALOS_VERSION}/metal-amd64.iso" "{{path}}/talos-metal-{{lnSchematicId}}-${TALOS_VERSION}-{{architecture}}.iso" "{{path}}/talos-metal-{{lnSchematicId}}-*-{{architecture}}.iso" talos-metal-{{architecture}} ${TALOS_VERSION} "false"

    # Generate machine patch
    cat >${TALOS_PATH}/initial-install-patch-ln.yaml <<EOF
    machine:
      install:
        image: factory.talos.dev/metal-installer/{{lnSchematicId}}:v${TALOS_VERSION}
    EOF
    echo "INFO: Generated ${TALOS_PATH}/initial-install-patch-ln.yaml"

    # Generate machine patch
    cat >${TALOS_PATH}/initial-install-patch-l.yaml <<EOF
    machine:
      install:
        image: factory.talos.dev/metal-installer/{{lSchematicId}}:v${TALOS_VERSION}
    EOF
    echo "INFO: Generated ${TALOS_PATH}/initial-install-patch-l.yaml"

[group('Ingress')]
download-metallb-helmchart cleanup="false" metallbConfig="${CONFIGS_PATH}/metallb":
    #!/usr/bin/env bash
    set -euxo pipefail

    mkdir -p {{metallbConfig}}

    # Download metallb chart using helper function
    just download-helmchart metallb https://metallb.github.io/metallb {{metallbConfig}} {{cleanup}}

# Download gateway api standard install
[group('Ingress')]
download-k8s-gatewayapi istioConfig="${CONFIGS_PATH}/istio":
    #!/usr/bin/env bash
    set -euxo pipefail

    version=$(curl -s https://api.github.com/repos/kubernetes-sigs/gateway-api/releases/latest | jq -r .tag_name | cut -d v -f2)

    wget https://github.com/kubernetes-sigs/gateway-api/releases/download/v${version}/standard-install.yaml -O {{istioConfig}}/gatewayapi-standard-install-${version}.yaml

# Download istio helmchart
[group('Ingress')]
download-istio-helmchart cleanup="false" istioConfig="${CONFIGS_PATH}/istio":
    #!/usr/bin/env bash
    set -euxo pipefail

    mkdir -p {{istioConfig}}

    # Download istio chart using helper function
    just download-helmchart base https://istio-release.storage.googleapis.com/charts {{istioConfig}} {{cleanup}}
    just download-helmchart istiod https://istio-release.storage.googleapis.com/charts {{istioConfig}} {{cleanup}}
    just download-helmchart cni https://istio-release.storage.googleapis.com/charts {{istioConfig}} {{cleanup}}
    just download-helmchart ztunnel https://istio-release.storage.googleapis.com/charts {{istioConfig}} {{cleanup}}
    just download-helmchart gateway https://istio-release.storage.googleapis.com/charts {{istioConfig}} {{cleanup}}

# Download Longhorn images
[group('Longhorn')]
download-longhorn-helmchart path="${CONFIGS_PATH}/longhorn":
    #!/usr/bin/env bash
    set -euxo pipefail

    mkdir -p {{path}}

    version=$(curl -s https://api.github.com/repos/longhorn/longhorn/releases/latest | jq -r .tag_name | cut -d v -f2)
    wget https://github.com/longhorn/charts/releases/download/longhorn-${version}/longhorn-${version}.tgz -O {{path}}/longhorn-helmchart-${version}.tgz

# Download NDVP helmchart
[group('Longhorn')]
download-nvdp-helmchart path="${CONFIGS_PATH}/nvidia" nvidiaConfig="${CONFIGS_PATH}/nvidia":
    #!/usr/bin/env bash
    set -euxo pipefail

    mkdir -p {{path}}
    mkdir -p {{nvidiaConfig}}

    version=$(curl -s https://api.github.com/repos/NVIDIA/k8s-device-plugin/releases/latest | jq -r .tag_name | cut -d v -f2)

    wget https://github.com/NVIDIA/k8s-device-plugin/releases/download/v${version}/nvidia-device-plugin-${version}.tgz -O {{path}}/nvidia-device-plugin-${version}.tgz
    wget https://github.com/NVIDIA/k8s-device-plugin/releases/download/v${version}/gpu-feature-discovery-${version}.tgz -O {{path}}/gpu-feature-discovery-${version}.tgz

    # Check if helm is present
    if ! command -v helm &> /dev/null; then
      echo "ERROR: helm could not be found, please install helm to proceed."
      exit 1
    fi

    helm template test --namespace test {{path}}/gpu-feature-discovery-${version}.tgz | grep "image:" | head -n 1 | awk -F': ' '{print $2}' | tr -d '"' > {{nvidiaConfig}}/nvdp-images-${version}.txt
    helm template test --namespace test {{path}}/nvidia-device-plugin-${version}.tgz | grep "image:" | head -n 1 | awk -F': ' '{print $2}' | tr -d '"' >> {{nvidiaConfig}}/nvdp-images-${version}.txt

# Set wired connection 1 to connect automatically
[group('Utilities')]
configure-wired-connection profile="Wired connection 1":
    #!/usr/bin/env bash
    set -euxo pipefail

    # exit if profile does not exist
    if ! nmcli connection show | grep -q "^{{profile}} "; then
        echo "Error: Network profile {{profile}} does not exist."
        exit 1
    fi

    # autoconnect
    nmcli connection modify "{{profile}}" connection.autoconnect yes

    # highest priority
    nmcli connection modify "{{profile}}" connection.autoconnect-priority 100

# Turn off sleep, suspend, hibernate, and hybrid-sleep
[group('Utilities')]
disable-all-sleep:
    #!/usr/bin/env bash
    set -euxo pipefail

    sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Turn on sleep, suspend, hibernate, and hybrid-sleep
[group('Utilities')]
enable-all-sleep:
    #!/usr/bin/env bash
    set -euxo pipefail

    sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Init Password store
[group('Bootstrap')]
init-pass:
    #!/usr/bin/env bash
    set -euxo pipefail

    # Genrate a new GPG key is ID=$USER does not exist
    if ! gpg --list-keys | grep -q "$USER"; then
        gpg --batch --passphrase '' --quick-generate-key "$USER" default default
    else
        echo "GPG key for $USER already exists."
    fi

    # Initialize pass with the generated GPG key if not already initialized
    if ! pass list | grep -q "^$USER$"; then
        pass init "$USER"
    else
        echo "Password store already initialized with GPG key $USER."
    fi

# Setup Talos
[group('Talos Utilities')]
check-available-disk ipAddr:
    #!/usr/bin/env bash
    set -euxo pipefail

    talosctl get disks --insecure --nodes {{ipAddr}}

# Generate Registry Patch for Talos
[group('Talos Utilities')]
add-host-entry hostIP ip hostname outputFile="./host.yaml":
    #!/usr/bin/env bash
    set -euxo pipefail

    cat > {{outputFile}} <<EOF
    machine:
      network:
        extraHostEntries:
          - ip: {{ip}}
            aliases:
            - {{hostname}}
    EOF

    # Apply Configurations on Control Plane
    talosctl apply-config --nodes {{hostIP}} --talosconfig=$HOME/talosconfig --file {{outputFile}}

    # cleanup
    rm {{outputFile}}

# Generate Talos secrets before cluster creation
[group('Talos Utilities')]
install-talosctl:
    #!/usr/bin/env bash
    set -euxo pipefail

    mkdir -p $HOME/.local/bin

    cp ${FILES_PATH}/talos/talosctl-${TALOS_VERSION}-linux-amd64 $HOME/.local/bin/talosctl
    sudo chmod +x $HOME/.local/bin/talosctl

# Generate Talos secrets before cluster creation
[group('Talos Utilities')]
generate-talos-secrets force="false" path="$HOME/secrets.yaml":
    #!/usr/bin/env bash
    set -euxo pipefail

    OVERWRITE=""
    if [[ "{{force}}" == "true" ]]; then
        OVERWRITE="--force"
    fi

    talosctl gen secrets -o {{path}} $OVERWRITE

    echo "Talos secrets generated at {{path}}. Pls store it securely."

# Generate Talos config
[group('Talos Utilities')]
generate-talos-config overwrite="false" talosIsoVariant="l" secretsYaml="$HOME/secrets.yaml" l2CPadvertise="false" endpointHostname="api.dct.it" controlPlaneOnly="false" talosEnv="$HOME/talos.env":
    #!/usr/bin/env bash
    set -euxo pipefail

    # Check if talosEnv exists
    if [[ ! -f {{talosEnv}} ]]; then
        echo "Error: {{talosEnv}} does not exist. Generating a default env file."
        cp ${TALOS_PATH}/talos.env {{talosEnv}}
        echo "Please update {{talosEnv}} with appropriate values before proceeding."
        exit 1
    fi

    source {{talosEnv}}

    OVERWRITE=""
    GPU_PATCH=""
    LONGHORN_PATCH=""
    L2_PATCH=""
    NVIDIA_RUNTIME_PATCH=""

    if [[ "{{l2CPadvertise}}" == "true" ]]; then
        L2_PATCH="--config-patch [{\"op\":\"replace\",\"path\":\"/machine/nodeLabels\",\"value\":{}}]"
    fi
    if [[ "{{talosIsoVariant}}" == *"n"* ]]; then
        GPU_PATCH="--config-patch @${TALOS_PATH}/gpu-worker-patch.yaml"
        NVIDIA_RUNTIME_PATCH="--config-patch @${TALOS_PATH}/nvidia-runtime-patch.yaml"
    fi
    if [[ "{{talosIsoVariant}}" == *"l"* ]]; then
        LONGHORN_PATCH="--config-patch @${TALOS_PATH}/talos-longhorn-patch.yaml"
    fi
    if [[ "{{overwrite}}" == "true" ]]; then
        OVERWRITE="--force"
    fi

    # Remarks: wiping the nodelabels allow for Metallb L2 advertisement to work on Control Planes

    # Generate Cluster Configuration with mirror registry patch, ntp patch, allow scheduling on control planes
    talosctl gen config $CLUSTER_NAME https://{{endpointHostname}}:6443 \
        --with-secrets {{secretsYaml}} \
        --install-disk /dev/$CP_DISK_NAME \
        --config-patch @${TALOS_PATH}/usernamespaces.yaml \
        --config-patch @${TALOS_PATH}/admission-patch.yaml \
        --config-patch @${TALOS_PATH}/send-redirects.yaml \
        --config-patch @${TALOS_PATH}/reject-source-routes.yaml \
        --config-patch @${TALOS_PATH}/accept-redirects.yaml \
        --config-patch @${TALOS_PATH}/secure-redirects.yaml \
        --config-patch @${TALOS_PATH}/log-martians.yaml \
        --config-patch @${TALOS_PATH}/icmp-echo-ignore-broadcasts.yaml \
        --config-patch @${TALOS_PATH}/icmp-ignore-bogus-error-responses.yaml \
        --config-patch @${TALOS_PATH}/enable-syncookies.yaml \
        --config-patch @${TALOS_PATH}/reversepath-filter.yaml \
        --config-patch '[{"op": "replace", "path": "/machine/install/wipe", "value": true}]' \
        --config-patch @${CONFIGS_PATH}/talos/initial-install-patch-{{talosIsoVariant}}.yaml \
        --config-patch-worker "[{\"op\": \"replace\", \"path\": \"/machine/install/disk\", \"value\": \"${W_DISK_NAME}\"}]" \
        --config-patch-control-plane "[{\"op\": \"add\", \"path\": \"/cluster/allowSchedulingOnControlPlanes\", \"value\": {{controlPlaneOnly}}}]" \
        $L2_PATCH $GPU_PATCH $NVIDIA_RUNTIME_PATCH $LONGHORN_PATCH $OVERWRITE
        
        # Enable after bootstrap
        # --config-patch "[{\"op\": \"add\", \"path\": \"/machine/kubelet/extraArgs\", \"value\": {}}]" \
        # --config-patch "[{\"op\": \"add\", \"path\": \"/machine/kubelet/extraArgs/rotate-server-certificates\", \"value\": true}]" \
                
        # Disabled for VMs        
        # --config-patch @${TALOS_PATH}/tpm-disk-encryption.yaml \

    # chmod generated yaml files
    chmod 600 ./controlplane.yaml ./worker.yaml

    mv ./talosconfig $HOME/talosconfig

    echo "Talos configs generated."

# Apply Talos config for control plane
[group('Talos Utilities')]
setup-talos controlPlaneOnly="false" secure="false" talosEnv="$HOME/talos.env":
    #!/usr/bin/env bash
    set -euxo pipefail

    # check if controlplane.yaml and worker.yaml exist
    if [[ ! -f controlplane.yaml || ! -f worker.yaml ]]; then
        echo "Error: controlplane.yaml or worker.yaml does not exist. Cannot proceed."
        exit 1
    fi

    # For each control plane IP in talosEnv, apply config
    source {{talosEnv}}
    for cip in $CONTROL_PLANE_IP; do
        just apply-talos-config-cp "$cip" {{secure}} 
    done

    # If controlPlaneOnly is false, apply worker config
    if [[ {{controlPlaneOnly}} == "false" ]]; then
        # For each worker IP in talosEnv, apply config
        for wip in $WORKER_IP; do
            just apply-talos-config-worker "$wip" {{secure}}
        done
    fi

# Apply Talos config for control plane
[group('Talos Helper Utilities')]
apply-talos-config-cp controlPlaneIp secure="true":
    #!/usr/bin/env bash
    set -euxo pipefail

    # Set INSECURE flag if secure is not passed
    INSECURE=""
    if [[ "{{secure}}" != "true" ]]; then
        INSECURE="--insecure"
    fi

    # Apply Configurations on Control Plane
    talosctl apply-config $INSECURE --nodes {{controlPlaneIp}} --file controlplane.yaml --talosconfig=$HOME/talosconfig

# Apply Talos config for worker nodes
[group('Talos Helper Utilities')]
apply-talos-config-worker workerIp secure="true":
    #!/usr/bin/env bash
    set -euxo pipefail

    # Set INSECURE flag if secure is not passed
    INSECURE=""
    if [[ "{{secure}}" != "true" ]]; then
        INSECURE="--insecure"
    fi

    # Apply Configurations on Worker Nodes
    talosctl apply-config $INSECURE --nodes {{workerIp}} --file worker.yaml --talosconfig=$HOME/talosconfig

# Set k8s apiserver endpoint
[group('Talos Helper Utilities')]
set-endpoints ip:
    #!/usr/bin/env bash
    set -euxo pipefail
    
    # Set endpoints
    talosctl --talosconfig=$HOME/talosconfig config endpoints {{ip}}

# Bootstrap etcd
[group('Talos Helper Utilities')]
bootstrap-etcd controlPlaneIp:
    #!/usr/bin/env bash
    set -euxo pipefail

    # Bootstrap Etcd cluster_name
    talosctl bootstrap --nodes {{controlPlaneIp}} --talosconfig=$HOME/talosconfig

# Get K8s access
[group('Talos Helper Utilities')]
get-k8s-access controlPlaneIp:
    #!/usr/bin/env bash
    set -euxo pipefail

    # Get K8s access
    talosctl kubeconfig talos-kubeconfig --nodes {{controlPlaneIp}} --talosconfig=$HOME/talosconfig

    mv talos-kubeconfig $HOME/talos-kubeconfig

    # Set KUBECONFIG env variable in bashrc
    if ! grep -q "export KUBECONFIG=\$HOME/talos-kubeconfig" $HOME/.bashrc; then
        echo "export KUBECONFIG=$HOME/talos-kubeconfig" >> $HOME/.bashrc
    fi

[group('Talos Helper Utilities')]
patch-vip vip interface="enp1s0" talosEnv="$HOME/talos.env":
    #!/usr/bin/env bash
    set -euxo pipefail

    source {{talosEnv}}

    # Patch VIP to control planes
    for cip in $CONTROL_PLANE_IP; do
        talosctl patch machineconfig --nodes $cip --talosconfig=$HOME/talosconfig --patch "[{\"op\": \"add\", \"path\": \"/machine/network\", \"value\": {}},{\"op\": \"add\", \"path\": \"/machine/network/interfaces\", \"value\": [{\"interface\":\"{{interface}}\",\"vip\":{\"ip\":\"{{vip}}\"}}]}]"    
    done

[group('Talos Helper Utilities')]
patch-endpoint endpointHostname="api.staredge.sl" talosEnv="$HOME/talos.env":
    #!/usr/bin/env bash
    set -euxo pipefail

    source {{talosEnv}}

    # Patch VIP to control planes
    for cip in $CONTROL_PLANE_IP; do
        talosctl patch machineconfig --nodes $cip --talosconfig=$HOME/talosconfig --patch "[{\"op\": \"replace\", \"path\": \"/cluster/controlPlane/endpoint\", \"value\": "https://{{endpointHostname}}:6443"}]"   
    done

# Check cluster health
[group('Talos Helper Utilities')]
check-cluster-health controlPlaneIp:
    #!/usr/bin/env bash
    set -euxo pipefail

    talosctl --nodes {{controlPlaneIp}} --talosconfig=$HOME/talosconfig health

# Shutdown all cp nodes
[group('Talos Helper Utilities')]
shutdown-cp talosEnv="$HOME/talos.env":
    #!/usr/bin/env bash
    set -euxo pipefail

    source {{talosEnv}}

    for ip in $CONTROL_PLANE_IP; do
        talosctl shutdown --nodes $ip --talosconfig=$HOME/talosconfig
    done

# Shutdown all worker nodes
[group('Talos Helper Utilities')]
shutdown-worker talosEnv="$HOME/talos.env":
    #!/usr/bin/env bash
    set -euxo pipefail

    source {{talosEnv}}

    for ip in $WORKER_IP; do
        talosctl shutdown --nodes $ip --talosconfig=$HOME/talosconfig
    done

# Patch talos linux machine config
[group ('Talos Helper Utilities')]
patch-machine-config-cp yaml talosEnv="$HOME/talos.env":
    #!/usr/bin/env bash
    set -euxo pipefail

    source {{talosEnv}}

    # patch machine config
    for ip in $CONTROL_PLANE_IP; do
        talosctl patch mc --nodes $ip --patch @{{yaml}} --talosconfig ~/talosconfig
    done

# Patch talos linux machine config
[group ('Talos Helper Utilities')]
patch-machine-config-worker yaml talosEnv="$HOME/talos.env":
    #!/usr/bin/env bash
    set -euxo pipefail

    source {{talosEnv}}

    # patch machine config
    for ip in $WORKER_IP; do
        talosctl patch mc --nodes $ip --patch @{{yaml}} --talosconfig ~/talosconfig
    done