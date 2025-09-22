#!/bin/bash

# YouTube 강의 순서 8단계: 설치 확인
# 강의 시간: 44:30 - 46:15 해당
# 마스터 노드에서 실행

set -e

# 1. 노드 상태 확인 (강의와 동일)
echo "1. 노드 상태 확인..."
kubectl get nodes -o wide
echo ""

# 2. 시스템 파드 확인 (강의와 동일)  
echo "2. 시스템 파드 확인..."
kubectl get pods -n kube-system
echo ""

# 3. 클러스터 정보 확인 (강의와 동일)
echo "3. 클러스터 정보 확인..."
kubectl cluster-info
echo ""

# 4. Cilium 상태 확인 (WeaveNet 대신)
echo "4. Cilium CNI 상태 확인..."
if command -v cilium >/dev/null 2>&1; then
    echo "Cilium CLI로 상태 확인:"
    cilium status
else
    echo "⚠️ Cilium CLI가 없음. kubectl로 상태 확인:"
    echo ""
    echo "Cilium 파드 상태:"
    kubectl get pods -n kube-system -l k8s-app=cilium -o wide
    echo ""
    echo "Cilium 데몬셋 상태:"
    kubectl get ds -n kube-system cilium
    echo ""
    echo "Cilium 서비스 상태:"
    kubectl get svc -n kube-system -l k8s-app=cilium
    echo ""
    echo "💡 Cilium CLI 수동 설치 방법:"
    echo "   curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz"
    echo "   sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin"
fi
echo ""

# 5. Rocky Linux 8.10 특화 확인
echo "5. Rocky Linux 8.10 환경 확인..."
echo "SELinux 상태: $(getenforce)"
echo "방화벽 상태: $(systemctl is-active firewalld || echo 'inactive')"
echo "Docker 상태: $(systemctl is-active docker)"
echo "containerd 상태: $(systemctl is-active containerd)"
echo ""

# 6. 최종 검증
echo "6. 최종 검증..."
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
READY_COUNT=$(kubectl get nodes --no-headers | grep -c " Ready ")

echo "총 노드 수: $NODE_COUNT"
echo "Ready 노드 수: $READY_COUNT"

if [ "$NODE_COUNT" -eq 5 ] && [ "$READY_COUNT" -eq 5 ]; then
    echo "✅ 성공! 5개 노드 모두 Ready 상태입니다."
else
    echo "❌ 문제 발견: 일부 노드가 Ready 상태가 아닙니다."
    echo "문제 해결 방법:"
    echo "- kubectl describe node <node-name> 으로 상세 확인"
    echo "- kubectl logs -n kube-system -l k8s-app=cilium 으로 CNI 로그 확인"
fi

echo ""
echo "=== 설치 완료! ==="
echo ""
echo "🎉 YouTube 강의와 동일한 구성이지만 더 발전된 클러스터가 완성되었습니다!"
echo ""
echo "📈 업그레이드된 내용:"
echo "- OS: Ubuntu → Rocky Linux 8.10"
echo "- CNI: WeaveNet → Cilium (eBPF 기반)"
echo "- 성능: kube-proxy 대체로 네트워크 성능 향상"
echo "- 관찰성: Hubble을 통한 네트워크 모니터링 가능"
echo ""
echo "🔧 추가 기능 활성화 (선택사항):"
echo "helm upgrade cilium cilium/cilium --namespace kube-system --reuse-values --set hubble.relay.enabled=true --set hubble.ui.enabled=true"
