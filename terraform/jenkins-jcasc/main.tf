terraform {
  required_version = "~> 1.7.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

#################################################
# Kubernetes Provider
#################################################

provider "kubernetes" {
  config_path    = pathexpand("~/.kube/config")
  config_context = "minikube"
}

#################################################
# Helm Provider
#################################################

provider "helm" {
  kubernetes {
    config_path    = pathexpand("~/.kube/config")
    config_context = "minikube"
  }
}

#################################################
# Namespace
#################################################

resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

####################################
# Jenkins Helm Chart
####################################

resource "helm_release" "jenkins" {

  depends_on = [
    kubernetes_namespace.jenkins
  ]

  name             = "my-jenkins"
  namespace        = "jenkins"
  create_namespace = false

  # chart = "${path.module}/../../../k8s-helm-charts/tools/jenkins-jcasc"
  repository = "https://github.com/sushant015/k8s-helm-charts.git"
  chart      = "jenkins-jcasc"

  wait             = true
  timeout          = 600
  cleanup_on_fail  = true
  dependency_update = true

  values = [
    yamlencode({
      image = {
        tag  = var.jenkins_image_tag
      }
      # Load the entire JCasC configuration from a single, consolidated file.
      jcasc = {
        enabled       = true
        configScripts = {
          "jenkins-casc.yaml" = file("${path.module}/jenkins-casc.yaml")
        }
      }
    })
  ]
}