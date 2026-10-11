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
  # Detecta IP público com fallback para IMDS da OCI
  - |
    PUBLIC_IP=$(curl -sf --max-time 5 ifconfig.me \
      || curl -sf --max-time 5 https://api.ipify.org \
      || curl -sf --max-time 5 -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r '.networkInterfaces[0].publicIp // empty')
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
      --disable traefik \
      --write-kubeconfig-mode 644 \
      --tls-san $PUBLIC_IP" sh -
  # Aguarda K3s estar pronto
  - until kubectl get nodes; do sleep 5; done
  # Instala Helm (versão fixada — $${} escapa interpolação do Terraform)
  - |
    HELM_VERSION=v3.17.3
    ARCH=arm64
    curl -fsSL https://get.helm.sh/helm-$${HELM_VERSION}-linux-$${ARCH}.tar.gz -o /tmp/helm.tar.gz
    tar -xzf /tmp/helm.tar.gz -C /usr/local/bin linux-$${ARCH}/helm --strip-components=1
    rm /tmp/helm.tar.gz
  # Adiciona repos Helm
  - helm repo add bitnami https://charts.bitnami.com/bitnami
  - helm repo add jetstack https://charts.jetstack.io
  - helm repo add backstage https://backstage.github.io/charts
  - helm repo add kong https://charts.konghq.com
  - helm repo update

final_message: "Spire node ready after $UPTIME seconds"

# Reinicia se kernel foi atualizado (package_upgrade pode instalar kernel novo)
power_state:
  mode: reboot
  delay: "+1"
  condition: test -f /var/run/reboot-required
