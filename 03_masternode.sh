#!/bin/bash

set -e

echo "⚠️  주의: 마스터 노드에서만 실행하세요!"

# 마스터 노드 IP (수정 필요)
MASTER_IP="192.168.2.100"
echo "마스터 노드 IP: $MASTER_IP"
echo "올바른 IP인지 확인하고 필요시 스크립트를 수정하세요."

# 1. kubeadm init 실행 (강의 28:56 구간)
echo "1. kubeadm init 실행 (가장 중요한 단계)..."
sudo kubeadm init --pod-network-cidr=10.128.0.0/16 \
  --apiserver-advertise-address=$MASTER_IP \
  --cri-socket=unix:///var/run/containerd/containerd.sock

# 2. kubectl 설정 (강의에서 설명하는 설정)
echo "2. kubectl 설정..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 3. join 토큰 저장 및 출력 (강의에서 강조하는 부분)
echo "3. Worker Node join 토큰 생성..."
echo ""
echo "=============================================="
kubeadm token create --print-join-command | sed 's/$/ \\\n    --cri-socket=unix:\/\/\/var\/run\/containerd\/containerd.sock/'
echo "=============================================="
echo ""

# 4. Helm 설치 (Cilium CNI를 위해)
echo "4. Helm 설치..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 5. Cilium 저장소 추가
echo "5. Cilium 저장소 추가..."
helm repo add cilium https://helm.cilium.io/
helm repo update

# 6. 기존 CNI 정리 (충돌 방지)
echo "6-1. 기존 CNI 정리 (충돌 방지)..."
sudo rm -rf /opt/cni/bin/flannel* 2>/dev/null || true
sudo rm -rf /etc/cni/net.d/10-flannel.conflist 2>/dev/null || true

# 6. Cilium CNI 설치 (강의의 WeaveNet 대신)
echo "6-2. Cilium CNI 설치..."
helm install cilium cilium/cilium --version 1.16.0 \
  --namespace kube-system \
  --set k8sServiceHost=$MASTER_IP \
  --set k8sServicePort=6443 \
  --set kubeProxyReplacement=true \
  --set routingMode=native \
  --set autoDirectNodeRoutes=true \
  --set ipam.mode=kubernetes \
  --set bpf.masquerade=true \
  --set ipv4NativeRoutingCIDR=10.128.0.0/16 \
  --set containerRuntime.integration=containerd

# 7. Cilium CLI 설치
echo "7. Cilium CLI 설치..."
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

echo "=== 6단계 완료! ==="
echo ""
echo "📋 다음 단계:"
echo "1. 위에 출력된 join 명령을 각 워커 노드에서 실행"
echo "2. 모든 워커 노드 조인 완료 후 lecture_step8_verify.sh 실행"
echo ""
echo "💡 팁: join 토큰은 24시간 후 만료됩니다."
echo "   만료 시 'kubeadm token create --print-join-command' 재실행"
