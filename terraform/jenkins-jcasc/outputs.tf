output "minikube_ip" {
  value       = minikube_cluster.jenkins_cluster.ip_address
  description = "The IP address of the Minikube cluster."
}

output "jenkins_url" {
  value       = "http://${minikube_cluster.jenkins_cluster.ip_address}:30080"
  description = "The URL to access the Jenkins UI."
}

output "jenkins_admin_password_command" {
  value       = "kubectl get secret --namespace jenkins my-jenkins-admin -o jsonpath=\"{.data.jenkins-admin-password}\" | base64 -d"
  description = "Run this command to get the Jenkins admin password."
}