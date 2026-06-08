# Production-Grade EKS Platform 

Building a production-ready Kubernetes platform while learning DevOps, Cloud, and SRE practices.

Goal: Move from a local multi-service setup to a secure, scalable, and cost-optimized AWS EKS platform using GitOps and Infrastructure as Code.

## Current Deployment

Running on a home server using Kind Kubernetes.

* Online Boutique: https://boutique-hs.l4sith.dev/
* Argo CD: https://argocd-hs.l4sith.dev/
* Grafana: https://grafana-hs.l4sith.dev/

---

## Architecture Journey

### Current Setup (Home Server)

`GitHub → Argo CD → Kind Cluster → Applications`

Services:

* Google Online Boutique
* Argo CD
* Prometheus + Grafana + Loki

### Target Setup (AWS)

`GitHub → GitHub Actions → Terraform → EKS → Karpenter → Applications`

Planned features:

* Multi-AZ deployment
* GitOps workflows
* Autoscaling
* Security hardening
* Observability stack
* Cost optimization

---

## Progress

### Completed ✅

* **Phase 1: Local Development with Kind** ([PR #1](https://github.com/lasithranahewa/eks-platform/pull/1))
  * [x] Local multi-node Kind cluster
  * [x] Custom Helm packaging
* **Phase 2: GitOps Locally with Argo CD** ([PR #5](https://github.com/lasithranahewa/eks-platform/pull/5))
  * [x] GitOps with Argo CD
  * [x] App-of-Apps pattern
* **Phase 3: AWS EKS with Terraform** ([PR #7](https://github.com/lasithranahewa/eks-platform/pull/7))
  * [x] Terraform-managed AWS infrastructure
  * [x] EKS cluster provisioning
  * [x] KMS encryption + remote state setup

### In Progress 🚧

* [ ] Deploy workloads to EKS
* [ ] Production observability
* [ ] OpenTelemetry tracing

### Planned 📌

* [ ] Security hardening
* [ ] Karpenter autoscaling
* [ ] GitHub Actions CI/CD
* [ ] Chaos testing & SLO validation

---

## Tech Stack

**Cloud & IaC**

* AWS
* Terraform

**Containers & Platform**

* Kubernetes (Kind + EKS)
* Helm
* Argo CD

**Observability**

* Prometheus
* Grafana
* Loki
* OpenTelemetry
* Tempo

**Security & Scaling**

* Kyverno
* External Secrets
* Karpenter
* HPA / KEDA
