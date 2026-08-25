#cloud-config
# Bootstrap K3s em Oracle Linux 9 ARM64
hostname: ${hostname}

package_update: true
package_upgrade: true
packages:
  - curl
  - git
  - jq
  - unzip

runcmd:
  # Instala K3s (single-node, sem agent)
  - |
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
      --disable traefik \
      --write-kubeconfig-mode 644 \
      --tls-san $(curl -s ifconfig.me)" sh -
  # Aguarda K3s estar pronto
  - until kubectl get nodes; do sleep 5; done
  # Instala Helm
  - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  # Adiciona repos Helm
  - helm repo add bitnami https://charts.bitnami.com/bitnami
  - helm repo add jetstack https://charts.jetstack.io
  - helm repo add backstage https://backstage.github.io/charts
  - helm repo add kong https://charts.konghq.com
  - helm repo update

final_message: "Spire node ready after $UPTIME seconds"
