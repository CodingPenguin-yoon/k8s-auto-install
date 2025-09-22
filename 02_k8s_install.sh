#!/bin/bash

# YouTube 강의 순서 4-5단계: Kubernetes 설치
# 강의 시간: 18:30 - 28:56 해당
# 모든 노드에서 실행

set -e

echo "=== YouTube 강의 순서 4-5단계: Kubernetes 설치 ==="
echo "강의 구간: 18:30 Kubernetes 설치 ~ 28:56 kubeadm,ctl,let 설치"

# 1. 커널 모듈 로드 (강의에서 설명하는 네트워크 설정)
echo "1. 커널 모듈 로드..."
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 2. 시스템 파라미터 설정 (강의에서 설명하는 브리지 네트워크 설정)
echo "2. 시스템 파라미터 설정..."
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# 3. containerd 설정 (안정성을 위한 추가)
echo "3. containerd 설정..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# 4. Kubernetes 저장소 설정 (Ubuntu apt 대신 dnf)
echo "4. Kubernetes 저장소 설정..."
sudo tee /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# 5. kubeadm, kubelet, kubectl 설치 (강의 25:32-28:56 구간)
echo "5. kubeadm, kubelet, kubectl 설치..."
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# 6. kubelet 서비스 활성화 (강의와 동일)
echo "6. kubelet 서비스 활성화..."
sudo systemctl enable kubelet

echo "=== 4-5단계 완료! ==="
echo "다음 단계:"
echo "- 마스터 노드: lecture_step6_master.sh (Control Plane 구성)"
echo "- 워커 노드: 마스터 완료 후 join 명령 실행"
