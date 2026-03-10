# 企業級 Kubernetes 架構分層軟體選型指南
## 針對保險業合規場景

> **文件資訊更新日期**: 2026-03-03  
> **所有版本號已確認為截至 2026 年 3 月最新穩定版本**

---

## 🏢 企業環境概述

本文檔針對以下企業內部環境進行軟體選型：

| 項目 | 說明 |
|------|------|
| **內部 CA** | Windows CA Server（Active Directory Certificate Services, AD CS） |
| **內部開發系統** | 以 .NET 9 為主的自行開發應用程式 |
| **K8S 工作負載類型** | ① 自建系統（.NET 應用）② 外部購買的商業系統 ③ 開源系統 |
| **身份驗證基礎** | Active Directory (AD) + Windows CA |
| **容器化策略** | .NET 應用使用 distroless/chiseled 基底鏡像，商業系統依廠商提供鏡像，開源系統使用官方 Helm Chart |

### 三類工作負載的管理策略

| 工作負載類型 | 鏡像來源 | 部署方式 | 安全掃描 | 更新策略 |
|-------------|---------|---------|---------|---------|
| **自建 .NET 系統** | 內部 CI/CD 構建 → Harbor | ArgoCD GitOps | Trivy 全流程掃描 | 團隊自主控制 |
| **外部購買系統** | 廠商提供 → 匯入 Harbor | Helm Chart + ArgoCD | Trivy 掃描 + 廠商 SLA | 依廠商發布週期 |
| **開源系統** | 官方 Registry → 同步至 Harbor | Helm Chart + ArgoCD | Trivy 掃描 + CVE 追蹤 | 追蹤社區版本 |

> ⚠️ **重要原則**: 所有鏡像必須先匯入內部 Harbor 私有倉庫，禁止直接從外部 Registry 拉取。

---

## 📋 目錄
1. [底層基礎設施層](#1️⃣-底層基礎設施層-infrastructure-layer)
2. [Kubernetes 核心層](#2️⃣-kubernetes-核心層-kubernetes-core-layer)
3. [容器運行時層](#3️⃣-容器運行時層-container-runtime-layer)
4. [網路與安全層](#4️⃣-網路與安全層-network--security-layer)
5. [存儲與數據層](#5️⃣-存儲與數據層-storage--data-layer)
6. [應用編排層](#6️⃣-應用編排層-application-orchestration-layer)
7. [觀測與監控層](#7️⃣-觀測與監控層-observability--monitoring-layer)
8. [日誌與審計層](#8️⃣-日誌與審計層-logging--audit-layer)
9. [身份與存取控制層](#9️⃣-身份與存取控制層-iam--access-control-layer)
10. [API 網關與入口層](#🔟-api-網關與入口層-api-gateway--ingress-layer)
11. [持續集成與部署層](#1️⃣1️⃣-持續集成與部署層-cicd-layer)
12. [備份與災難復原層](#1️⃣2️⃣-備份與災難復原層-backup--disaster-recovery-layer)

---

## 1️⃣ 底層基礎設施層 (Infrastructure Layer)

### 定義
負責承載 Kubernetes 集群的物理或虛擬資源。

### 推薦軟體選型

#### 1.1 操作系統
- **首選**: Ubuntu Server 24.04 LTS
  - 原因：廣泛的企業支持、安全補丁頻繁、LTS 支援至 2034 年
  - 特點：內核安全強化（AppArmor）、cgroup v2 原生支持（K8S 1.35 已棄用 cgroup v1）
  - .NET 相容性：.NET 9 官方支援 Ubuntu 24.04

- **備選**: Rocky Linux 9.x（RHEL 完全兼容替代）
  - 原因：完全兼容 RHEL 9，SELinux 原生支持
  - 特點：企業級穩定性，免費使用

> ⚠️ **注意**: CentOS 已於 2024 年 6 月 30 日停止維護 (EOL)，不建議用於新部署。

#### 1.2 虛擬化平台
- **公有雲**: AWS / Azure / GCP
  - AWS: 使用 EKS (Elastic Kubernetes Service) 或自管理 EC2
  - Azure: AKS (Azure Kubernetes Service)（如已有 AD 環境，Azure 整合最佳）
  - GCP: GKE (Google Kubernetes Engine)
  
- **私有雲**: VMware vSphere + Tanzu
  - 原因：金融級別的隔離與控制
  - 特點：vSAN 存儲集成、Kubernetes 原生支持
  - 與 Windows CA 整合：vSphere 原生支持 AD 與 Windows CA 證書

- **混合雲**: Azure Arc / AWS Outposts
  - 適用場景：保險業通常需要部分系統留在地端（合規要求），部分在雲端

#### 1.3 負載均衡
- **硬件/軟件 LB**: F5 LTM (Enterprise) 或 HAProxy (開源)
  - 功能：Layer 4/7 負載均衡、SSL 卸載（可使用 Windows CA 簽發的憑證）、會話保持
  - 金融合規考量：支援審計日誌、速率限制、DDoS 防護
  - Windows CA 整合：F5 可直接對接 AD CS 自動申請/續期 SSL 憑證

---

## 2️⃣ Kubernetes 核心層 (Kubernetes Core Layer)

### 定義
Kubernetes 集群本身的控制平面與數據平面。

### 推薦軟體選型

#### 2.1 Kubernetes 版本策略
- **推薦版本**: Kubernetes 1.35.x（目前最新穩定版 v1.35.2，2026/02/26 發布）
  - 關鍵新特性：
    - **In-Place Pod Resource Updates (GA)**：可在不重建 Pod 的情況下調整 CPU/Memory
    - **Pod 工作負載身份憑證 (Beta)**：原生工作負載身份，自動憑證輪換
    - **棄用 cgroup v1**：必須使用 cgroup v2
    - **最後支援 containerd 1.x 的版本**：未來版本需 containerd 2.0+
  - 下一版本：Kubernetes 1.36 預計 2026 年 4 月發布

#### 2.2 控制平面管理
- **自管理**: kubeadm + etcd 高可用
  - 適用場景：私有數據中心、特殊合規需求
  - 配置：etcd 3.5+ 使用 TLS 加密、定期快照備份

- **托管服務** (推薦保險業):
  - AWS EKS：自動 API Server 高可用、內建 IAM 集成
  - Azure AKS：Azure AD 原生集成、隱藏式控制平面
  - GCP GKE：自動升級、內建日誌審計

#### 2.3 Node 管理
- **自動縮放**: Cluster Autoscaler (開源) 或 Karpenter
  - Karpenter（推薦）：
    - 更快的供應時間（秒級）
    - 更好的 Bin Packing
    - 支援多種實例類型的組合
  
- **節點鏡像管理**: Flatcar Container Linux 或 Ubuntu (EKS Optimized AMI)
  - 特點：最小化 OS 攻擊面、容器化友好

---

## 3️⃣ 容器運行時層 (Container Runtime Layer)

### 定義
負責在節點上執行、管理容器的軟體。

### 推薦軟體選型

#### 3.1 容器運行時
- **首選**: containerd 2.2.x（目前最新 v2.2.1，2025/12/18 發布）
  - 原因：
    - OCI 標準實現，安全性強
    - 低資源消耗（相比 Docker）
    - **Kubernetes 1.35 是最後支援 containerd 1.x 的版本**，建議直接使用 2.x
    - 與 Kubernetes 1.30+ 完全兼容
  - 特點：支援鏡像簽名驗證、遠程鏡像 Lazy 加載、bundled runc v1.3.4

- **備選**: CRI-O
  - 適用場景：Red Hat/CentOS 企業環境
  - 特點：Kubernetes 原生開發、與 OCP 深度集成

#### 3.2 鏡像倉庫
- **私有倉庫** (必須，保險業不能使用公共倉庫):
  - **首選**: Harbor v2.14.x（目前最新 v2.14.2，2026/01/15 發布）
    - 功能：RBAC、映像掃描（Trivy/Clair）、複製同步
    - 合規性：支援 LDAP/AD 集成、完整審計日誌
    - 安全：支援鏡像簽名驗證（Notary/Cosign）、掃描後才能部署
    - **企業整合**：
      - 與內部 AD 集成：員工使用域賬號登錄 Harbor
      - 與 Windows CA 集成：Harbor HTTPS 使用內部 CA 簽發的憑證
      - 三類鏡像管理：
        - `library/internal/*`：自建 .NET 系統鏡像
        - `library/vendor/*`：外部購買系統鏡像
        - `library/opensource/*`：開源系統鏡像（設置自動同步 + 掃描策略）
  
  - **備選**:
    - AWS ECR：與 EKS 無縫集成
    - Azure ACR：與 AKS 無縫集成
    - JFrog Artifactory：支援多種製品格式

#### 3.3 鏡像掃描與安全
- **容器鏡像掃描**: Trivy v0.69.x（目前最新 v0.69.2，2026/03 發布）
  - Trivy 優勢：快速、準確、支援 OCI 格式
  - 集成方式：在 Harbor 內集成或 CI/CD 流程中
  - 功能：CVE 掃描、IaC 錯誤配置檢測、機密洩露偵測、SBOM 生成
  - **三類鏡像掃描策略**：
    - 自建鏡像：每次 CI/CD 構建時掃描
    - 廠商鏡像：匯入 Harbor 時掃描 + 定期重新掃描
    - 開源鏡像：同步時掃描 + 每日定時重新掃描

- **簽名驗證**: Cosign (Sigstore/CNCF)
  - 確保鏡像未被篡改、來源可信
  - 自建鏡像：CI/CD 流程中自動簽名
  - 廠商/開源鏡像：驗證上游簽名

#### 3.4 Runtime Security
- **容器沙箱**:
  - gVisor：用於高安全隔離 Pod
  - Kata Containers：VM 級別隔離（金融級別推薦）
  - 配置：Pod 級別選擇，而非全局

#### 3.5 .NET 應用容器化最佳實踐
- **基底鏡像策略** (.NET 9):
  - **生產環境**: `mcr.microsoft.com/dotnet/aspnet:9.0-noble-chiseled`（Ubuntu chiseled，最小攻擊面）
  - **Native AOT**：適合微服務場景，啟動快、記憶體少、鏡像更小
  - **非 root 運行**：.NET 9 chiseled 鏡像預設以非 root 用戶運行

- **多階段構建範例**:
  ```dockerfile
  # Build Stage
  FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
  WORKDIR /src
  COPY . .
  RUN dotnet publish -c Release -o /app

  # Runtime Stage (chiseled = distroless equivalent)
  FROM mcr.microsoft.com/dotnet/aspnet:9.0-noble-chiseled
  WORKDIR /app
  COPY --from=build /app .
  EXPOSE 8080
  ENTRYPOINT ["dotnet", "MyApp.dll"]
  ```

- **健康檢查**：
  - 使用 ASP.NET Core Health Checks Middleware (`/health`, `/ready`)
  - 對應 K8S liveness/readiness probe

- **SBOM 生成**：使用 Syft 或 `dotnet sbom` 工具產生軟體組成清單

---

## 4️⃣ 網路與安全層 (Network & Security Layer)

### 定義
集群內部通訊、入出方向流量控制、加密與威脅防護。

### 推薦軟體選型

#### 4.1 Container Network Interface (CNI)
- **首選**: Cilium 1.19.x（目前最新 v1.19.1，2026/02 發布）
  - **核心功能**:
    - L3/L4 & L7 網路策略（支援 HTTP/gRPC 規則）
    - Identity-based 安全（Pod Identity，不依賴 IP）
    - WireGuard 加密（透明，應用無感知）
    - Hubble 流量可視化（金融審計需要）
    - CLI 工具 cilium-cli v0.19.1
  
  - **保險業特定優勢**:
    - 支援 Layer 7 策略（如：只允許 POST /api/transfer）
    - 完整的流量日誌用於審計
    - eBPF 效能優異，不影響吞吐量

- **備選**:
  - Calico + Typha：傳統網路策略、大規模部署優化
  - AWS VPC CNI：與 AWS 基礎設施原生集成（EKS 推薦）

#### 4.2 服務網格 (Service Mesh)
- **首選**: Istio 1.29.x（目前最新 v1.29.0，2026/02/16 發布）
  - **核心功能**:
    - mTLS 雙向自動加密（Pod-to-Pod）
    - 細粒度訪問控制（AuthorizationPolicy）
    - 流量管理（金絲雀部署、A/B 測試）
    - 分布式追蹤（Jaeger 集成）
    - **Ambient Mode (Stable)**：無 Sidecar 架構，使用輕量 ztunnel 代理，資源消耗更低
  
  - **保險業應用**:
    - 強制 mTLS：所有通訊自動加密
    - 審計友好：完整的請求追蹤與日誌
    - PII 保護：支援自定義 filter，可隱藏敏感 Header
  
  - **配置層次**:
    ```yaml
    - VirtualService: 流量路由規則
    - DestinationRule: 連接池、離群檢測
    - AuthorizationPolicy: 訪問控制
    - RequestAuthentication: OAuth2/JWT 驗證
    ```

- **備選**:
  - Linkerd：輕量級、性能優（但功能略少）
  - AWS App Mesh：與 AWS 服務原生集成

#### 4.3 零信任網路 (Zero Trust Networking)
- **工具**: Falco v0.43.0（2026/01/28 發布，CNCF 畢業專案）+ Cilium NetworkPolicy
  - Falco：運行時威脅檢測（異常 Shell、特權操作、容器逃逸）
    - 使用 eBPF 監控（推薦），效能優、延遲亞毫秒級
    - 搭配 Falcosidekick 進行告警轉發（Slack/Teams/PagerDuty）
    - 搭配 Falco Talon 進行自動回應
  - Cilium 網路策略：白名單模式（默認拒絕，明確允許）

#### 4.4 DDoS 與入侵防護
- **邊界防護**: ModSecurity (開源) 或 Cloudflare / AWS Shield
  - ModSecurity：OWASP Core Rule Set，可部署在 API Gateway
  
- **Kubernetes 內部**: Cilium L7 策略 + 速率限制
  - 支援基於 Pod Identity 的速率限制

---

## 5️⃣ 存儲與數據層 (Storage & Data Layer)

### 定義
Kubernetes 中的持久化數據、數據庫、分布式存儲管理。

### 推薦軟體選型

#### 5.1 持久化存儲 (Persistent Volumes)
- **首選**: Rook Ceph v1.19.x（目前最新 v1.19.2，支援 K8S 1.30~1.35）
  - **優勢**:
    - CEPH 是業界標準分布式存儲（最低支援 Ceph v19.2.0 "Squid"）
    - Kubernetes 原生管理（無需額外工具）
    - 支援多種存儲類型：RBD (Block), CephFS (文件系統), S3 (對象)
    - 新增 NVMe-oF 支持（實驗性）用於高性能存儲
    - CephCSI v3.16 增強加密與 fencing 功能
  
  - **保險業特定功能**:
    - 靜態加密 (Encryption at Rest)：支援 LUKS
    - 複製策略：3 副本保證可用性 (RTO/RPO)
    - Snapshot & Clone：快照用於備份與恢復
  
  - **架構建議**:
    ```
    - 3 個 Monitor 節點（Quorum 決策）
    - 3+ 個 OSD 節點（數據副本）
    - 專用網路（減少競爭）
    ```

- **備選**:
  - Longhorn (Rancher)：輕量級、支援分布式副本
  - AWS EBS：與 EKS 無縫集成（簡單場景推薦）
  - Azure Managed Disk：與 AKS 無縫集成

#### 5.2 對象存儲 (Object Storage)
- **首選**: MinIO (S3 相容，可自建)
  - 用途：
    - Velero 備份目標
    - 日誌歸檔
    - 鏡像存儲（與 Harbor 集成）
  
  - **部署模式**:
    - 高可用：Distributed Mode (4+ 節點)
    - 加密：使用 KMS 或自簽 TLS

- **備選**:
  - AWS S3：雲原生場景（支援加密、版本控制、跨區複製）
  - Azure Blob Storage：Azure 環境推薦

#### 5.3 數據庫層
- **PostgreSQL** (推薦關係型數據庫)
  - 自管理方案：
    - CloudNativePG (Kubernetes Operator)：自動備份、HA、PITR
    - 堆棧：PostgreSQL 17+ + PgBouncer (連接池) + pgbackrest (備份)
  
  - 托管方案：
    - AWS RDS for PostgreSQL：支援多 AZ、自動備份
    - Azure Database for PostgreSQL：完全托管
  
  - 金融合規特性：
    - 行級安全 (RLS)：基於用戶隔離數據
    - 完整 ACID 保證
    - 審計日誌 (pgAudit)
  
  - .NET 整合：
    - Npgsql：.NET 官方 PostgreSQL 驅動
    - EF Core + Npgsql：ORM 完整支持

- **Microsoft SQL Server** (適合 .NET 生態系統)
  - 適用場景：
    - 現有 .NET 系統已使用 SQL Server
    - 需要與 Windows AD 深度整合（Windows 驗證）
  - 部署方式：
    - SQL Server 2022 on Linux Container（官方支援 K8S 部署）
    - Azure SQL Managed Instance（托管方案）
  - .NET 整合：
    - Microsoft.Data.SqlClient：官方驅動
    - EF Core：原生 SQL Server Provider
  - 容器部署：
    ```yaml
    # SQL Server on Kubernetes
    image: mcr.microsoft.com/mssql/server:2022-latest
    env:
      ACCEPT_EULA: "Y"
      MSSQL_SA_PASSWORD: <from-secret>
    ```

- **Redis** (緩存 + Session 存儲)
  - 高可用方案：Redis Sentinel (主從自動轉換)
  - 大規模：Redis Cluster (分片存儲)
  - 保險業考量：
    - 啟用 AOF (Append-Only File) 持久化
    - 使用 Redis ACL 隔離租戶數據

#### 5.4 消息隊列
- **Apache Kafka** (推薦高吞吐、重要業務)
  - 特點：持久化、可重複消費、分布式
  - 部署：Strimzi Operator v0.50.1+（支援 Kafka 4.2.0，支援 K8S 1.30+）
    - ⚠️ Strimzi 0.51 已棄用 Ingress listener type
    - 新增 v1 API 版本（舊版 v1beta2 支持至 Strimzi 1.0/0.52）
  - 安全：SASL/SSL 認證、topic 級別 ACL
  - .NET 整合：Confluent.Kafka NuGet 套件

- **RabbitMQ** (備選，輕量級)
  - 場景：低延遲、復雜路由規則
  - 部署：RabbitMQ Cluster Kubernetes (Operator)

---

## 6️⃣ 應用編排層 (Application Orchestration Layer)

### 定義
如何在 Kubernetes 中定義、部署、升級應用。

### 推薦軟體選型

#### 6.1 包管理工具
- **Helm 3** (推薦標準)
  - 用途：版本化應用部署、配置管理
  - 結構：Chart (應用模板) + Values (環境配置)
  - 企業實踐：
    - 集中化 Helm Repository (Artifactory 或 Harbor Helm 模塊)
    - 版本控制：每個 Chart 版本對應 Git Commit

#### 6.2 聲明式配置管理
- **Kustomize** (Kubernetes 內置)
  - 用途：通過 Patch 生成環境特定配置（Prod/Staging/Dev）
  - 優勢：無需模板語言，純 YAML Patch

- **補充**: ArgoCD 使用 Kustomize 進行環境管理

#### 6.3 應用升級策略
- **原生 Kubernetes 滾動更新**:
  - 策略：漸進式副本更新（maxSurge/maxUnavailable）
  - 監控：使用 Prometheus 指標決定是否回滾
  
  ```yaml
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  ```

- **進階**:
  - Flagger：自動金絲雀部署（基於指標決定推進/回滾）
  - Argo Rollouts：複雜的部署策略（藍綠、金絲雀、漸進式）

#### 6.4 Operator 框架
- **Operator SDK** (CNCF)
  - 用途：構建自定義 Operator 管理應用生命週期
  - 示例：CloudNativePG (PostgreSQL Operator)、Strimzi (Kafka Operator)

---

## 7️⃣ 觀測與監控層 (Observability & Monitoring Layer)

### 定義
實時監控集群、應用性能、資源使用情況。

### 推薦軟體選型

#### 7.1 指標收集 (Metrics)
- **首選**: Prometheus v3.10.x（目前最新 v3.10.0，2026/02/24 發布；LTS 版本 v3.5.1 支援至 2026/07）
  - **核心功能**:
    - 時間序列數據庫（TSDB）
    - PromQL 查詢語言（v3.x 增強 regex 與 label 提取效能）
    - 多維度標籤（如：pod, namespace, node）
    - 新增 distroless Docker 鏡像變體（提升安全性）
    - 支援 OpenAPI 3.2 HTTP API 規格
  
  - **Kubernetes 集成**:
    - kube-state-metrics：Kubernetes API 資源轉為 Prometheus 指標
    - node-exporter：節點系統指標（CPU、內存、磁盤）
    - kubelet metrics：Pod 級別資源使用
  
  - **部署**:
    ```bash
    # 使用 Prometheus Operator（推薦）
    helm install prometheus prometheus-community/kube-prometheus-stack \
      --namespace monitoring --create-namespace
    ```
  
  - **.NET 應用整合**：
    - 使用 `prometheus-net` NuGet 套件暴露 .NET 指標
    - ASP.NET Core 自動暴露 HTTP 請求指標、GC 指標等
    - 商業系統/開源系統：透過 ServiceMonitor CRD 自動發現

  - **保留策略**:
    - 高精度數據（15s）：7 天
    - 低精度數據（1h）：1 年
    - 使用對象存儲 (S3/MinIO) 進行長期存儲

#### 7.2 日誌聚合 (Logs)
- **首選**: Grafana Loki v3.6.x（目前最新 v3.6.7，2026/02/23 發布） + Promtail
  - **優勢**:
    - 成本低：只索引標籤，而非全文搜索
    - 與 Prometheus 指標無縫集成
    - 標籤緣由能力強
  
  - **部署**:
    ```yaml
    Promtail 在每個 Node 收集日誌
      ↓
    Loki 聚合與存儲（本地或對象存儲）
      ↓
    Grafana 查詢與展示
    ```
  
  - **金融審計配置**:
    - 日誌保留：最少 1 年
    - PII 過濾：使用 Promtail 的 Regex Stage 隱藏敏感信息

- **備選**:
  - ELK Stack (Elasticsearch + Logstash + Kibana)
    - 適用場景：需要全文搜索、複雜分析
    - 缺點：資源消耗大、維護複雜

#### 7.3 可視化 (Visualization)
- **Grafana v12.4.x**（目前最新 v12.4.0，2026/02/24 發布）
  - **數據源**:
    - Prometheus（指標）
    - Loki（日誌）
    - Alertmanager（告警狀態）
  
  - **預建 Dashboard**:
    - Kubernetes Cluster Monitoring
    - Node Exporter Full
    - Prometheus Stats
  
  - **自定義 Dashboard**:
    - 應用性能指標（延遲、錯誤率、吞吐量）
    - 資源成本分析（按 Namespace/Team 計費）

#### 7.4 分布式追蹤 (Distributed Tracing)
- **首選**: Jaeger (CNCF)
  - **功能**:
    - 跟蹤請求跨服務的完整路徑
    - 識別性能瓶頸（哪個服務慢）
    - 依賴關係映射
  
  - **集成方式**:
    - 應用端：使用 OpenTelemetry SDK（支援所有語言）
    - .NET 整合：`OpenTelemetry.Extensions.Hosting` + `OpenTelemetry.Exporter.Jaeger` NuGet
    - Kubernetes 端：使用 Istio 自動注入 Jaeger 追蹤
    - 商業系統：若不支援 OpenTelemetry，可透過 Istio Sidecar 自動追蹤

  - **部署架構**:
    ```
    應用（OpenTelemetry Agent）
      ↓
    Jaeger Agent (DaemonSet)
      ↓
    Jaeger Collector
      ↓
    Elasticsearch 存儲
      ↓
    Jaeger UI 查詢
    ```

#### 7.5 告警管理 (Alerting)
- **Prometheus Alertmanager**
  - **配置層次**:
    - Recording Rules：將複雜的 PromQL 預計算
    - Alert Rules：定義告警條件
    - Alertmanager：告警分組、去重、路由、抑制
  
  - **路由策略**:
    ```yaml
    告警 → 分組（相同標籤） → 去重（避免重複） → 路由（dev/prod/security 不同路由） → 發送
    ```
  
  - **告警通道**:
    - 郵件：運維常規告警
    - Slack/Teams：團隊通知
    - PagerDuty：緊急告警 + On-Call 管理
    - 短信/電話：P1 級別事件

#### 7.6 成本監控 (Cost Monitoring)
- **Kubecost** (推薦開源)
  - 功能：按 Namespace/Pod/Node 計算成本
  - 集成：與 Prometheus 數據共享
  - 報表：發送成本分析報表給財務部門

---

## 8️⃣ 日誌與審計層 (Logging & Audit Layer)

### 定義
記錄所有系統事件、用戶操作，用於合規審計與安全調查。

### 推薦軟體選型

#### 8.1 Kubernetes Audit Logs
- **配置**:
  - 審計日誌記錄：API Server 的所有請求
  - 日誌等級：
    - Metadata：記錄請求元數據
    - RequestResponse：記錄請求體 + 響應體（敏感，謹慎使用）
  
  - **自建集群配置**:
    ```yaml
    apiVersion: audit.k8s.io/v1
    kind: Policy
    rules:
      - level: RequestResponse
        verbs: ["create", "update", "patch", "delete"]
        resources: ["secrets", "configmaps"]
      - level: Metadata
        omitStages:
        - RequestReceived
    ```
  
  - **托管服務**:
    - AWS EKS：AWS CloudTrail (自動記錄 API 調用)
    - Azure AKS：Azure Audit Logs (通過 Azure Monitor)

#### 8.2 應用日誌 (Application Logs)
- **日誌格式規範**:
  - JSON 格式（便於解析與分析）
  - 包含字段：timestamp, level, message, user_id, operation, resource_id
  - 不記錄：密碼、token、銀行卡號（PII）

- **日誌收集**:
  - Fluent Bit（輕量級）或 Logstash（功能豐富）
  - 配置規則：過濾 PII，加密敏感欄位

#### 8.3 審計追蹤 (Audit Trail)
- **什麼要審計**:
  - 用戶登錄/登出
  - 敏感操作（轉賬、修改配置、刪除數據）
  - 訪問敏感數據的操作

- **實現方式**:
  - 應用層面：在業務邏輯中記錄審計日誌
  - 數據庫層面：使用 pgAudit (PostgreSQL) 或 MySQL Audit Plugin
  - 基礎設施層面：Kubernetes Audit Logs

- **儲存**:
  - 獨立的審計日誌系統（與應用日誌分離）
  - 提供讀取但不修改的接口（Write-Once 日誌存儲）

#### 8.4 日誌合規性 (Compliance)
- **保留期限**:
  - 標準審計日誌：最少 3 年（或更長，根據地區法規）
  - 敏感操作日誌：最少 5 年

- **訪問控制**:
  - 只有審計團隊和安全團隊可查看完整日誌
  - 使用 RBAC 限制日誌訪問

- **備份與恢復**:
  - 定期備份日誌至異地（使用 Velero 或手動複製至對象存儲）
  - 驗證備份可恢復性

---

## 9️⃣ 身份與存取控制層 (IAM & Access Control Layer)

### 定義
管理用戶身份認證、應用間授權、基於角色的訪問控制。

### 推薦軟體選型

#### 9.1 身份提供商 (Identity Provider)
- **首選**: Keycloak v26.5.x（目前最新 v26.5.4，2026/02 發布）
  - **功能**:
    - OIDC & SAML 2.0 支持
    - 用戶聯合（與 Active Directory/LDAP 集成）
    - 多因素認證 (MFA) 支持
    - 細粒度的 Token 簽發控制
    - **v26 新功能**：
      - 持久化 User Session（重啟不遺失 Session）
      - JWT Authorization Grant (RFC 7523)
      - Organizations 功能（階層式用戶/角色管理）
      - OpenTelemetry 整合（提升可觀測性）
      - DPoP 增強（防止 API Token 竊取）
  
  - **與企業 AD + Windows CA 整合**:
    ```
    ┌──────────────────────────────────────────────────┐
    │  Active Directory (AD DS)                        │
    │  ├─ 用戶帳號/群組管理                              │
    │  └─ Keycloak User Federation (LDAP Provider)     │
    ├──────────────────────────────────────────────────┤
    │  Windows CA Server (AD CS)                       │
    │  ├─ 簽發 Keycloak HTTPS 憑證                      │
    │  ├─ 簽發 Kubernetes API Server 憑證                │
    │  └─ 簽發 Istio mTLS Root CA（可選）               │
    ├──────────────────────────────────────────────────┤
    │  Keycloak                                        │
    │  ├─ OIDC Provider for Kubernetes                 │
    │  ├─ OIDC Provider for .NET 應用                   │
    │  ├─ SAML Provider for 商業系統                     │
    │  └─ 統一 SSO 入口                                 │
    └──────────────────────────────────────────────────┘
    ```
  
  - **配置要點**:
    - 與 AD 集成：使用 User Federation → LDAP Provider
    - 員工使用域名賬戶登錄所有系統（SSO）
    - 強制 MFA：所有用戶必須啟用 TOTP
    - Token 生命週期：短時效（15 分鐘）+ 刷新 Token
    - .NET 應用使用 `Microsoft.AspNetCore.Authentication.OpenIdConnect` 對接
    - 商業系統：依廠商支援情況選擇 OIDC 或 SAML 2.0 對接

- **備選**:
  - Okta / Azure AD：專業 IAM 服務（支付模式，企業級 SLA）
  - Dex：輕量級 OIDC Provider（GitHub/Google 集成）

#### 9.2 Kubernetes RBAC (Role-Based Access Control)
- **核心概念**:
  - Role：定義一組權限（在 Namespace 級別）
  - ClusterRole：集群級別的權限
  - RoleBinding：將 Role 綁定到用戶/服務賬戶
  - ClusterRoleBinding：集群級別的綁定

- **最佳實踐**:
  ```yaml
  # 示例：開發人員可查看自己命名空間的 Pod
  kind: Role
  metadata:
    namespace: dev
    name: pod-viewer
  rules:
  - apiGroups: [""]
    resources: ["pods", "pods/logs"]
    verbs: ["get", "list"]
  ---
  kind: RoleBinding
  metadata:
    namespace: dev
    name: dev-team-binding
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: pod-viewer
  subjects:
  - kind: Group
    name: "developers"  # LDAP 組
    apiGroup: rbac.authorization.k8s.io
  ```

- **企業分組**:
  - cluster-admin：叢集管理員（最小化）
  - namespace-admin：命名空間管理員（開發/測試/生產分離）
  - developer：開發人員（查看、部署到自己的命名空間）
  - viewer：只讀訪問

#### 9.3 服務賬戶 (Service Account) 安全
- **配置**:
  - 每個應用使用獨立的服務賬戶
  - 限制服務賬戶的權限（按需最小化）
  - 禁用自動掛載 Token（除非必要）

- **Pod 身份認證**:
  - **AWS**: IRSA (IAM Roles for Service Accounts)
    - Pod 可直接使用 AWS IAM 角色，無需硬編碼 Credential
  
  - **Azure**: Workload Identity
    - Pod 通過 OIDC 向 Azure 證明身份，獲取 Access Token

  - **通用方案**: Bound Service Account Token (Kubernetes 1.26+)
    - Token 與 Pod 綁定，Token 持有者必須是該 Pod

#### 9.4 應用層授權 (Authorization)
- **OAuth 2.0 / OpenID Connect**:
  - 應用集成 OIDC Client Library
  - 用戶通過瀏覽器重定向到 Keycloak 登錄
  - 應用收到 ID Token (身份驗證) + Access Token (授權)

- **API 授權**:
  - JWT Token 驗證：簽名驗證確保 Token 來源合法
  - Scope 檢查：Token 包含的權限範圍
  - 額外的業務邏輯：如用戶只能訪問自己的資料

#### 9.5 網路層訪問控制
- **Cilium NetworkPolicy**:
  ```yaml
  apiVersion: cilium.io/v2
  kind: CiliumNetworkPolicy
  metadata:
    name: allow-transfer-api
  spec:
    endpointSelector:
      matchLabels:
        app: transfer-api
    ingress:
    - fromEndpoints:
      - matchLabels:
          role: frontend
      toPorts:
      - ports:
        - port: "8080"
      rules:
        http:
        - method: "POST"
          path: "/api/transfer"
  ```

- **Istio AuthorizationPolicy**:
  ```yaml
  apiVersion: security.istio.io/v1beta1
  kind: AuthorizationPolicy
  metadata:
    name: transfer-policy
  spec:
    rules:
    - from:
      - source:
          principals: ["cluster.local/ns/default/sa/frontend"]
      to:
      - operation:
          methods: ["POST"]
          paths: ["/api/transfer*"]
  ```

---

## 🔟 API 網關與入口層 (API Gateway & Ingress Layer)

### 定義
集群外部訪問入口、API 管理、流量路由、DDoS 防護。

### 推薦軟體選型

#### 10.1 入口控制器 (Ingress Controller)
- **首選**: NGINX Ingress Controller
  - **優勢**:
    - 廣泛使用、社區成熟
    - 支援複雜的路由規則
    - 可配置 ModSecurity (WAF)
  
  - **配置示例**:
    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: api-gateway
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
        nginx.ingress.kubernetes.io/rate-limit: "10"  # 限流
        nginx.ingress.kubernetes.io/ssl-redirect: "true"  # 強制 HTTPS
    spec:
      tls:
      - hosts:
        - api.example.com
        secretName: api-tls
      rules:
      - host: api.example.com
        http:
          paths:
          - path: /api/v1
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 8080
    ```

- **備選**:
  - Traefik：輕量級、自動 Let's Encrypt 集成
  - HAProxy：高性能、複雜負載均衡場景

#### 10.2 API 網關 (API Gateway)
- **首選**: APISIX v3.15.x（目前最新 v3.15.0，2026/02/05 發布）
  - **功能**:
    - 動態路由：支援 YAML/API 熱更新
    - 認證與授權：OAuth 2.0、JWT、LDAP（支援 Windows AD LDAP）
    - 限流與黑名單：基於客戶端 IP、User ID
    - PII 遮罩：自動隱藏敏感響應數據
    - 日誌審計：完整的請求/響應記錄
    - **v3.15 新功能**：
      - AI Gateway 能力（Google Vertex AI、Gemini、Anthropic）
      - `apisix_request_id` 變數用於追蹤
      - 認證插件支援自定義 Realm（RFC 7235）
      - Redis 連接池 keepalive 支持
      - K8S Readiness 健康檢查端點
  
  - **部署** (推薦在 Kubernetes 外獨立部署):
    ```yaml
    # 獨立部署，作為集群前置層
    APISIX （API 網關） → NGINX Ingress → Kubernetes 集群
    ```
  
  - **配置示例**:
    ```yaml
    routes:
    - uri: /api/transfer
      methods: [POST]
      plugins:
        oauth2:  # OAuth 認證
          client_id: my-app
        limit-count:  # 限流
          count: 100
          time_window: 60
        log-to-file:  # 日誌記錄
          file: /var/log/apisix/requests.log
    ```

- **備選**:
  - Kong：功能豐富，但資源消耗較大
  - Tyk：輕量級、易於部署

#### 10.3 Web 應用防火牆 (WAF)
- **首選**: ModSecurity + OWASP CRS
  - **部署位置**:
    - NGINX Ingress 中集成：`modsecurity.enabled=true`
    - APISIX 中使用 waf 插件
  
  - **規則示例**:
    - SQL 注入防護
    - XSS 防護
    - 命令注入防護
    - 文件上傳驗證

- **備選**:
  - AWS WAF：AWS 邊界防護
  - Cloudflare WAF：外部服務

#### 10.4 速率限制與節流 (Rate Limiting)
- **層級配置**:
  - API 網關層：客戶端級別的全局限流
  - Kubernetes 服務層：基於源 Pod 的限流 (Cilium)
  - 應用層：基於用戶的限流

- **配置**:
  ```yaml
  # APISIX 限流：每個客戶端 IP 每分鐘 100 請求
  limit-count:
    count: 100
    time_window: 60
    key_type: "remote_addr"
  ```

#### 10.5 TLS/SSL 證書管理
- **首選**: cert-manager v1.19.x（目前最新 v1.19.4，2026/02/24 發布）
  - **與 Windows CA Server (AD CS) 整合**:
    - 使用 `cert-manager-csi-driver` + `adcs-issuer` 插件
    - Kubernetes 內部所有 TLS 憑證由企業 Windows CA 簽發
    - 自動申請、續期、輪換

  - **簽發者配置 (Windows CA)**:
    ```yaml
    # 使用 adcs-issuer 對接 Windows CA
    apiVersion: adcs.certmanager.csf.nokia.com/v1
    kind: AdcsIssuer
    metadata:
      name: enterprise-ca
      namespace: cert-manager
    spec:
      caBundle: <base64-encoded-root-ca-cert>
      credentialsRef:
        name: adcs-credentials
      statusCheckInterval: 6h
      retryInterval: 1h
      url: https://ca-server.corp.local/certsrv
      templateName: WebServer
    ```

  - **備選簽發者**:
    - Let's Encrypt：僅限外部公網服務
    - 自簽 CA：cert-manager 內建（開發/測試環境）
  
  - **憑證用途規劃**:
    | 憑證用途 | 簽發者 | 自動化 |
    |---------|--------|--------|
    | Ingress HTTPS（外部） | Windows CA 或 Let's Encrypt | cert-manager 自動 |
    | Istio mTLS（內部） | Windows CA 或 Istio 自簽 CA | Istio 自動管理 |
    | Harbor HTTPS | Windows CA | cert-manager 自動 |
    | Keycloak HTTPS | Windows CA | cert-manager 自動 |
    | 數據庫 TLS | Windows CA | cert-manager 自動 |
    | API Gateway HTTPS | Windows CA | cert-manager 自動 |

---

## 1️⃣1️⃣ 持續集成與部署層 (CI/CD Layer)

### 定義
自動化應用構建、測試、部署到 Kubernetes。

### 推薦軟體選型

#### 11.1 版本控制
- **Git 服務**:
  - GitHub：業界標準（支付模式）
  - GitLab：自建選項（功能完整）
  - Gitea：輕量級自建

#### 11.2 CI/CD 平台
- **首選**: GitOps 模式 (推薦)
  - **工具**: ArgoCD v3.3.x（目前最新 v3.3.2，2026/02/22 發布）
  - **原理**:
    - 應用配置存儲在 Git Repository
    - ArgoCD 監視 Git 變化，自動同步到集群
    - 安全優勢：所有變化可審計，易於回滾
  - **v3.3 新功能**：
    - PreDelete hooks：更安全的應用刪除前自定義步驟
    - 背景 OIDC Token 自動刷新（改善 SSO 體驗）
    - 淺層 Git 克隆（加速大型 Monorepo 同步）
  
  - **部署流程**:
    ```
    開發者 Push → Git Repo
                      ↓
                  ArgoCD Watch
                      ↓
                  自動同步到 Kubernetes
                      ↓
                  Flux 遞迴同步檢查
    ```

- **傳統 CI/CD**:
  - Jenkins：老牌自動化工具（需維護）
  - GitHub Actions：GitHub 原生，簡單場景推薦
  - GitLab CI：GitLab 原生，功能完整
  - CircleCI：雲服務，付費模式

#### 11.3 容器構建
- **首選**: Kaniko (無需 Docker Daemon)
  - 優勢：可在 Kubernetes Pod 內構建鏡像（更安全）
  - 集成：與 GitLab CI / GitHub Actions 無縫集成

- **備選**:
  - Docker Build：傳統方式（需要 Docker Daemon）
  - Buildah：模塊化構建工具

- **.NET 應用構建流程**:
  ```yaml
  # GitHub Actions / GitLab CI 範例流程
  steps:
    - dotnet restore
    - dotnet build --configuration Release
    - dotnet test --no-build
    - dotnet publish -c Release -o /app
    - kaniko build → push to Harbor
    - trivy scan → 掃描鏡像
    - cosign sign → 簽名鏡像
    - update Git manifest → ArgoCD 自動部署
  ```

#### 11.4 安全掃描
- **代碼掃描**:
  - SonarQube：靜態代碼分析（尋找漏洞、代碼坏味道）
  - Semgrep：輕量級規則引擎，支援自定義規則

- **鏡像掃描**:
  - Trivy：在 CI/CD 流程中掃描已構建鏡像
  - 配置：掃描失敗則阻止部署

- **依賴掃描**:
  - Dependabot (GitHub)：監測依賴更新、安全警報
  - OWASP Dependency-Check：自托管掃描

#### 11.5 GitOps 工作流
- **分支策略** (Git Flow):
  ```
  main (生產)
    ↓
  release/ (預發布測試)
    ↓
  develop (開發集成)
    ↓
  feature/* (特性分支)
  ```

- **部署流程**:
  ```yaml
  # 1. 開發者在 feature 分支開發
  # 2. Pull Request：自動運行 CI 測試（構建、掃描、單測）
  # 3. Code Review：團隊審閱
  # 4. Merge to develop：部署到 Staging 環境
  # 5. Release PR：從 develop 到 release
  # 6. 測試驗證
  # 7. Merge to main：部署到生產（可自動或手動）
  ```

---

## 1️⃣2️⃣ 備份與災難復原層 (Backup & Disaster Recovery Layer)

### 定義
定期備份集群狀態與數據、在災難時快速恢復。

### 推薦軟體選型

#### 12.1 Kubernetes 資源備份
- **首選**: Velero v1.17.x（穩定版；v1.18.0-rc1 即將發布，支援 K8S 1.18~1.35）
  - **功能**:
    - 備份 K8S API 資源 (Pod, StatefulSet, ConfigMap, Secret 等)
    - 備份持久卷 (Persistent Volumes)
    - 多云支持 (AWS S3, Azure Blob, GCS, MinIO)
  
  - **部署**:
    ```bash
    # 連接 AWS S3
    velero install \
      --provider aws \
      --bucket velero-backups \
      --secret-file ./aws-credentials \
      --use-volume-snapshots=true
    
    # 連接 MinIO (自建對象存儲)
    velero install \
      --provider aws \
      --bucket velero-backups \
      --secret-file ./minio-credentials \
      --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio:9000
    ```
  
  - **備份策略**:
    ```bash
    # 每天 2:00 AM 自動備份
    velero schedule create daily-backup --schedule="0 2 * * *"
    
    # 備份特定命名空間
    velero backup create daily-backup-prod --include-namespaces=production
    
    # 排除敏感數據 (Secret)
    velero backup create backup-no-secrets --exclude-secret-fields
    ```
  
  - **保留策略** (金融合規):
    - 日備份：保留 7 天
    - 周備份：保留 4 周
    - 月備份：保留 1 年

- **備選**:
  - Kasten K10：商業備份解決方案（功能豐富）
  - ARK (Heptio)：Velero 的前身（已整合）

#### 12.2 數據庫備份
- **PostgreSQL**:
  - 工具：pgbackrest (推薦)
    - PITR (Point-in-Time Recovery)：恢復到任意時間點
    - 增量備份：只備份變化的塊
    - 並行備份：加速備份
  
  - **配置**:
    ```ini
    [db-cluster]
    pg1-host=localhost
    pg1-path=/var/lib/postgresql/data
    repo1-path=/backup/db-cluster
    backup-type=full
    ```

- **Redis**:
  - RDB Snapshot：定期全量備份
  - AOF (Append-Only File)：實時備份（日誌重放）
  - Replication：主從複製（異地副本）

#### 12.3 跨區部署 (Geo-Redundancy)
- **架構** (推薦多區域):
  ```
  Region A (主)
    ↓ Velero 備份
  對象存儲 (S3 跨區複製)
    ↓
  Region B (從)
    ↓ Velero 恢復
  備用集群 (保持 Ready 狀態)
  ```

- **故障轉移策略**:
  - RTO (Recovery Time Objective)：< 1 小時
  - RPO (Recovery Point Objective)：< 15 分鐘
  - 自動轉移：DNS 切換，或使用全局負載均衡

#### 12.4 備份驗證 (Backup Validation)
- **定期測試恢復**:
  - 每月執行一次完整恢復測試
  - 驗證：
    - 應用正常啟動
    - 數據完整性檢查 (checksum)
    - 功能回歸測試 (冒煙測試)

- **自動化驗證**:
  - 脚本檢查備份年齡（最新備份不超過 24 小時）
  - 告警：備份失敗時立即通知運維團隊

---

## 📊 完整架構總結表（版本截至 2026/03）

| 層級 | 核心功能 | 推薦主選 | 最新版本 | 備選方案 |
|------|----------|---------|---------|---------|
| 基礎設施 | 計算/存儲/網路 | AWS/Azure/GCP 或 VMware vSphere | - | 混合雲 Azure Arc |
| K8S 核心 | 集群控制/管理 | EKS/AKS/GKE (托管) 或 kubeadm | **v1.35.2** | Tanzu, OpenShift |
| 容器運行時 | 容器執行 | containerd | **v2.2.1** | CRI-O, Kata |
| 鏡像倉庫 | 容器倉庫 | Harbor (私建，AD 整合) | **v2.14.2** | ECR, ACR, Artifactory |
| 鏡像掃描 | 安全掃描 | Trivy | **v0.69.2** | Qualys |
| 網路 | Pod 通訊/隔離 | Cilium (L7 策略) | **v1.19.1** | Calico, AWS VPC CNI |
| 服務網格 | 應用通訊層 | Istio (mTLS, Ambient Mode) | **v1.29.0** | Linkerd |
| 運行時安全 | 威脅偵測 | Falco | **v0.43.0** | Sysdig |
| 存儲 | 持久化數據 | Rook Ceph (分布式) | **v1.19.2** | Longhorn, EBS |
| 對象存儲 | 日誌/備份 | MinIO (自建) | - | S3, Azure Blob |
| 數據庫 | 關係數據 | PostgreSQL + CloudNativePG | **PG 17** | SQL Server 2022 |
| 緩存 | 會話/熱數據 | Redis Sentinel (HA) | - | Redis Cluster |
| 消息隊列 | 異步通訊 | Kafka + Strimzi | **v0.50.1** | RabbitMQ, NATS |
| 指標監控 | 性能監控 | Prometheus + Grafana | **v3.10.0 / v12.4.0** | Datadog |
| 日誌聚合 | 日誌收集 | Loki + Promtail | **v3.6.7** | ELK Stack |
| 分布式追蹤 | 請求追蹤 | Jaeger | - | Zipkin, Tempo |
| 身份管理 | 用戶認證 | Keycloak (OIDC + AD 整合) | **v26.5.4** | Okta, Azure AD |
| 密鑰管理 | 機密存儲 | HashiCorp Vault | **v1.21.3** | Azure Key Vault |
| API 網關 | 入口管理 | APISIX (WAF, AI Gateway) | **v3.15.0** | Kong, Tyk |
| Ingress | 流量入口 | NGINX Ingress | - | Traefik |
| 憑證管理 | TLS 自動化 | cert-manager (+ Windows CA) | **v1.19.4** | 手動管理 |
| CI/CD | 部署自動化 | ArgoCD (GitOps) | **v3.3.2** | Jenkins, GitLab CI |
| 備份 | 災難恢復 | Velero (跨云備份) | **v1.17.2** | Kasten K10 |

---

## 🎯 部署順序建議 (以保險業生產環境為例)

**第一階段** (基礎架構):
1. ✅ 部署 Kubernetes 集群 (v1.35.x，EKS/AKS/GKE 或 kubeadm)
2. ✅ 配置 Cilium CNI v1.19 + Hubble 監控
3. ✅ 部署 Rook Ceph v1.19 (分布式存儲) 或使用托管存儲
4. ✅ 部署 Harbor v2.14 私有鏡像倉庫（與 AD 集成登錄）
5. ✅ 部署 cert-manager v1.19 + 配置 Windows CA (AD CS) Issuer

**第二階段** (安全與身份):
6. ✅ 部署 Keycloak v26.5（與 AD User Federation 集成）
7. ✅ 配置 Kubernetes RBAC + Keycloak OIDC 認證
8. ✅ 部署 External Secrets Operator + HashiCorp Vault v1.21
9. ✅ 配置三類鏡像的 Harbor Project 與掃描策略

**第三階段** (服務網格與應用):
10. ✅ 部署 Istio v1.29 服務網格 (mTLS + Ambient Mode)
11. ✅ 部署 APISIX v3.15 API 網關 (WAF + PII 遮罩 + AD LDAP 認證)
12. ✅ 部署數據庫 (PostgreSQL 17 + CloudNativePG，或 SQL Server 2022)
13. ✅ 部署消息隊列 (Kafka + Strimzi v0.50)
14. ✅ 部署自建 .NET 9 應用（使用 chiseled 鏡像 + ArgoCD GitOps）
15. ✅ 部署外部購買系統與開源系統

**第四階段** (觀測性與運維):
16. ✅ 部署 Prometheus v3.10 + Grafana v12.4 (指標監控)
17. ✅ 部署 Loki v3.6 + Promtail (日誌聚合)
18. ✅ 部署 Jaeger (分布式追蹤) + .NET OpenTelemetry 整合
19. ✅ 部署 Falco v0.43 (運行時安全)

**第五階段** (備份與 CI/CD):
20. ✅ 部署 Velero v1.17 (備份與災難恢復)
21. ✅ 部署 ArgoCD v3.3 (GitOps 部署)
22. ✅ 配置 Trivy v0.69 + SonarQube (安全掃描)
23. ✅ 測試故障轉移與恢復流程

---

## 🔒 合規性檢查清單 (金融/保險業)

- [ ] **身份與訪問控制**: 所有用戶通過 Keycloak SSO + AD 登錄，無默認密碼
- [ ] **網路隔離**: 使用 Cilium NetworkPolicy 實現白名單模式（默認拒絕）
- [ ] **加密傳輸**: 所有通訊 TLS 加密（Windows CA 簽發），Pod-to-Pod 使用 Istio mTLS
- [ ] **加密存儲**: 敏感數據在靜止狀態加密 (LUKS, KMS)
- [ ] **密鑰管理**: 所有密鑰通過 Vault v1.21 管理，定期輪轉
- [ ] **審計日誌**: Kubernetes Audit Logs + 應用層審計，保留 3 年+
- [ ] **日誌保護**: 審計日誌不可修改，獨立存儲
- [ ] **備份驗證**: 每月執行恢復測試，RTO < 1 小時
- [ ] **漏洞掃描**: CI/CD 中集成 Trivy v0.69 鏡像掃描，漏洞及時修復
- [ ] **PII 保護**: APISIX 自動遮罩敏感數據，開發環境不接觸生產數據
- [ ] **資源隔離**: 多租戶使用命名空間 + NetworkPolicy 隔離（自建/商業/開源系統分離）
- [ ] **監控告警**: Prometheus + Grafana 配置關鍵指標告警，24/7 值班制度
- [ ] **災備計畫**: 文檔化的 RTO/RPO，定期演習
- [ ] **供應鏈安全**: 所有鏡像通過 Harbor 管理 + Trivy 掃描 + Cosign 簽名驗證
- [ ] **Windows CA 整合**: 所有內部 TLS 憑證由 AD CS 簽發，cert-manager 自動管理
- [ ] **三類系統治理**: 自建/購買/開源系統分別有明確的鏡像管理與更新策略

---

## 📚 推薦學習資源

- CNCF Kubernetes 官方文檔：https://kubernetes.io/docs/
- Cilium 文檔：https://docs.cilium.io/
- Istio 服務網格指南：https://istio.io/latest/docs/
- Velero 備份恢復：https://velero.io/docs/
- OWASP Top 10 Kubernetes 安全：https://owasp.org/www-project-kubernetes-top-ten/

---

**文檔版本**: 2.0  
**最後更新**: 2026-03-03  
**版本資訊確認日期**: 2026-03-03（所有軟體版本已透過官方來源確認）  
**維護者**: Enterprise K8S Architecture Research Team  
**企業環境**: Windows CA (AD CS) + Active Directory + .NET 9 + 多類型工作負載
**AI**: claude-opus-4.6 (high)