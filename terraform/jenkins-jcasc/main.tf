terraform {
  required_providers {
    minikube = {
      source  = "gavinbunney/minikube"
      version = ">= 1.11.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.8.0"
    }
  }
}

# 1. Provision the Minikube cluster with required addons
resource "minikube_cluster" "jenkins_cluster" {
  cluster_name = "jenkins-dev"
  driver       = "docker"
  cpus         = 4
  memory       = "4g"

  # Enable addons required for persistence and monitoring
  addons = [
    "storage-provisioner",
    "metrics-server",
    "ingress"
  ]
}

# 2. Configure the Kubernetes provider to connect to the new Minikube cluster
# The Helm provider will use the default Kubernetes provider configuration.
provider "kubernetes" {
  host                   = minikube_cluster.jenkins_cluster.host
  client_certificate     = base64decode(minikube_cluster.jenkins_cluster.client_certificate)
  client_key             = base64decode(minikube_cluster.jenkins_cluster.client_key)
  cluster_ca_certificate = base64decode(minikube_cluster.jenkins_cluster.cluster_ca_certificate)
}

# 3. Configure the Helm provider (uses the above kubernetes provider)
provider "helm" {}

# 3. Deploy the jenkins-jcasc Helm chart from the local path
resource "helm_release" "jenkins" {
  # This ensures Helm waits for the cluster to be ready
  depends_on = [minikube_cluster.jenkins_cluster]

  name             = "my-jenkins"
  # Use the chart from the Git repository.
  # The format is <repo_url>.git//<path_to_chart_in_repo>
  chart            = "https://github.com/sushant015/k8s-helm-charts.git//tools/jenkins-jcasc"
  namespace        = "jenkins"
  create_namespace = true
  wait             = true
  timeout          = 300

  # Set values from values.yaml
  values = [
    yamlencode({
      image = {
        tag = var.jenkins_image_tag
      }
      # jcasc = {
      #   enabled = true
      #   configScripts = {
      #     "jenkins-casc-config" = file("${path.module}/jenkins-casc.yaml")
      #   }
      # }
    })
  ]
}