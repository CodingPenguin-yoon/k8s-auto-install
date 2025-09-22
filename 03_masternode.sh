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
if ! command -v helm >/dev/null 2>&1; then
    echo "Helm 다운로드 및 설치 중..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # PATH 즉시 적용
    export PATH=$PATH:/usr/local/bin
    
    # 현재 세션에서 helm 사용 가능하도록 설정
    if [ -f /usr/local/bin/helm ]; then
        sudo chmod +x /usr/local/bin/helm
        echo "✅ Helm 설치 완료: /usr/local/bin/helm"
    else
        echo "❌ Helm 바이너리를 찾을 수 없습니다."
        exit 1
    fi
else
    echo "✅ Helm이 이미 설치되어 있습니다."
fi

# Helm 설치 확인 (전체 경로로)
echo "Helm 버전 확인 중..."
if /usr/local/bin/helm version --short >/dev/null 2>&1; then
    echo "✅ Helm 설치 성공!"
    /usr/local/bin/helm version --short
else
    echo "❌ Helm 설치 실패!"
    echo "디버그 정보:"
    ls -la /usr/local/bin/helm* || echo "Helm 바이너리 없음"
    echo "PATH: $PATH"
    exit 1
fi

# 5. Cilium 저장소 추가
echo "5. Cilium 저장소 추가..."
/usr/local/bin/helm repo add cilium https://helm.cilium.io/ || {
    echo "❌ Cilium 저장소 추가 실패!"
    exit 1
}
/usr/local/bin/helm repo update || {
    echo "❌ Helm 저장소 업데이트 실패!"
    exit 1
}

# 6. 기존 CNI 정리 (충돌 방지)
echo "6-1. 기존 CNI 정리 (충돌 방지)..."
sudo rm -rf /opt/cni/bin/flannel* 2>/dev/null || true
sudo rm -rf /etc/cni/net.d/10-flannel.conflist 2>/dev/null || true

# 6. kubectl 연결 테스트
echo "6-1. kubectl 연결 테스트..."
kubectl get nodes || {
    echo "❌ kubectl 연결 실패! kubeconfig 설정을 확인하세요."
    exit 1
}

# 6. Cilium CNI 설치 (강의의 WeaveNet 대신)
echo "6-2. Cilium CNI 설치..."
echo "Cilium 설치 중... 몇 분 소요될 수 있습니다."

# 기존 Cilium 설치 확인
if /usr/local/bin/helm list -n kube-system | grep -q cilium; then
    echo "⚠️ Cilium이 이미 설치되어 있습니다. 업그레이드합니다..."
    /usr/local/bin/helm upgrade cilium cilium/cilium --version 1.16.0 \
      --namespace kube-system \
      --set k8sServiceHost=$MASTER_IP \
      --set k8sServicePort=6443 \
      --set kubeProxyReplacement=true \
      --set routingMode=native \
      --set autoDirectNodeRoutes=true \
      --set ipam.mode=kubernetes \
      --set bpf.masquerade=true \
      --set ipv4NativeRoutingCIDR=10.128.0.0/16 \
      --set containerRuntime.integration=containerd \
      --set cluster.name=k8s-cluster \
      --set cluster.id=1 \
      --wait --timeout=10m
else
    # 새로 설치
    /usr/local/bin/helm install cilium cilium/cilium --version 1.16.0 \
      --namespace kube-system \
      --set k8sServiceHost=$MASTER_IP \
      --set k8sServicePort=6443 \
      --set kubeProxyReplacement=true \
      --set routingMode=native \
      --set autoDirectNodeRoutes=true \
      --set ipam.mode=kubernetes \
      --set bpf.masquerade=true \
      --set ipv4NativeRoutingCIDR=10.128.0.0/16 \
      --set containerRuntime.integration=containerd \
      --set cluster.name=k8s-cluster \
      --set cluster.id=1 \
      --wait --timeout=10m || {
        echo "❌ Cilium 설치 실패!"
        echo "디버그 정보:"
        kubectl get pods -n kube-system
        /usr/local/bin/helm list -n kube-system
        exit 1
      }
fi

# Cilium 설치 확인
echo "Cilium 설치 상태 확인 중..."
kubectl rollout status -n kube-system daemonset/cilium --timeout=300s || {
    echo "❌ Cilium 데몬셋 준비 실패!"
    kubectl describe daemonset cilium -n kube-system
    exit 1
}
echo "✅ Cilium 데몬셋 준비 완료"

# 7. Cilium CLI 설치 (확실한 방법)
echo "7. Cilium CLI 설치..."

# 고정 버전으로 안정적 설치
CILIUM_CLI_VERSION="v0.15.22"
CLI_ARCH="amd64"
echo "Cilium CLI 버전: $CILIUM_CLI_VERSION"

# 작업 디렉토리 생성
WORK_DIR="/tmp/cilium-install"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 다운로드 시도
echo "Cilium CLI 다운로드 중..."
if curl -L --fail -o cilium-linux-${CLI_ARCH}.tar.gz \
   "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"; then
   
    echo "✅ 다운로드 성공, 설치 중..."
    sudo tar -C /usr/local/bin -xzf cilium-linux-${CLI_ARCH}.tar.gz
    sudo chmod +x /usr/local/bin/cilium
    
    # PATH에 추가
    echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/bin
    
    # 설치 확인
    if /usr/local/bin/cilium version --client >/dev/null 2>&1; then
        echo "✅ Cilium CLI 설치 성공!"
        /usr/local/bin/cilium version --client
    else
        echo "⚠️ Cilium CLI 설치되었지만 실행 확인 실패"
    fi
else
    echo "❌ Cilium CLI 다운로드 실패"
    echo "수동 설치 명령:"
    echo "curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz"
    echo "sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin"
fi

# 정리
cd /
rm -rf $WORK_DIR

echo "=== 6단계 완료! ==="
echo ""

# 최종 설치 상태 확인
echo "🔍 최종 설치 상태 확인:"
echo "1. Cilium 파드 상태:"
kubectl get pods -n kube-system -l k8s-app=cilium --no-headers | head -3

echo ""
echo "2. Cilium CLI 상태:"
if command -v cilium >/dev/null 2>&1; then
    echo "✅ Cilium CLI 사용 가능"
else
    echo "❌ Cilium CLI 사용 불가 - kubectl로 확인 필요"
fi

echo ""
echo "📋 다음 단계:"
echo "1. 위에 출력된 join 명령을 각 워커 노드에서 실행"
echo "2. 모든 워커 노드 조인 완료 후 05_chexk.sh 실행"
echo ""
echo "💡 팁: join 토큰은 24시간 후 만료됩니다."
echo "   만료 시 'kubeadm token create --print-join-command' 재실행"
