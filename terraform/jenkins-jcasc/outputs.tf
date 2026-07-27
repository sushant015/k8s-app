output "namespace" {
  value = kubernetes_namespace.jenkins.metadata[0].name
}

output "jenkins_url_command" {
  description = "Run this command to get the Jenkins URL. The service is exposed on NodePort 30080."
  value       = "echo \"Jenkins URL: http://$(minikube ip):30080\""
}

output "jenkins_admin_password_command" {
  value       = "kubectl get secret --namespace jenkins my-jenkins-admin -o jsonpath=\"{.data.jenkins-admin-password}\" | base64 -d"
  description = "Run this command to get the Jenkins admin password."
}
