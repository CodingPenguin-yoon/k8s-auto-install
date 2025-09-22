#!/bin/bash

# 공식문서 https://docs.docker.com/engine/install/centos/
set -e

echo "=== YouTube 강의 순서 1-3단계: 환경 설정 + Docker 설치 ==="
echo "강의 구간: 00:13 환경소개 ~ 18:30 Docker 설치 완료"

# 1. 호스트명 확인
echo "현재 호스트명: $(hostname)"
echo "올바른 호스트명으로 설정했는지 확인하세요:"
echo "- k8s-master (컨트롤 플레인)"  
echo "- k8s-worker01, k8s-worker02, k8s-worker03, k8s-worker04 (워커 노드)"

# 2. SELinux 비활성화 (Ubuntu와 다른 부분)
echo "2. SELinux 비활성화 (Rocky Linux 특화)..."
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config

# 3. 방화벽 비활성화 (Ubuntu ufw 대신 firewalld)
echo "3. 방화벽 비활성화 (Rocky Linux 특화)..."
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# 4. 스왑 비활성화
echo "4. 스왑 비활성화..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 5. 시스템 업데이트
echo "5. 시스템 패키지 업데이트..."
sudo dnf update -y

# 6. 필수 패키지 설치
echo "6. 필수 패키지 설치..."
sudo dnf install -y dnf-plugins-core device-mapper-persistent-data lvm2

# 7. Docker 저장소 추가
echo "7. Docker 저장소 추가..."
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 8. Docker 설치
echo "8. Docker 설치 (강의 Docker 설치 구간)..."
sudo dnf install -y docker-ce docker-ce-cli containerd.io --allowerasing

# 9. Docker 데몬 설정
echo "9. Docker 데몬 설정..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# 10. Docker 서비스 시작 
echo "10. Docker 서비스 시작..."
sudo systemctl daemon-reload
sudo systemctl enable --now docker

# 11. Docker 설치 확인
echo "11. Docker 설치 확인..."
docker --version
sudo systemctl status docker --no-pager

echo "=== 1-3단계 완료! ==="
echo "다음 단계: lecture_step4_5.sh (Kubernetes 설치)"