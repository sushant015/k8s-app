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

#################################################
# Locals
#################################################

locals {
  casc_config_files = fileset("${path.module}/../../jenkins-jcasc/casc_configs", "**/*.yaml")
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

  chart = "${path.module}/../../../k8s-helm-charts/tools/jenkins-jcasc"
  wait             = true
  timeout          = 600
  cleanup_on_fail  = true
  dependency_update = true

  values = [
    yamlencode({
      image = {
        tag  = var.jenkins_image_tag
      }
      # Dynamically load all JCasC files from the casc_configs directory.
      # This is a powerful pattern that keeps your configuration separate from your deployment logic.
      jcasc = {
        enabled       = true
        configScripts = { for filename in local.casc_config_files :
          filename => file("${path.module}/../../jenkins-jcasc/casc_configs/${filename}")
        }
      }
    })
  ]
}