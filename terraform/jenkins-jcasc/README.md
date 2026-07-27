# Terraform for Minikube Jenkins Deployment

This Terraform configuration automates the setup of a local development environment for Jenkins on Minikube.

It will provision a Minikube cluster and deploy the `jenkins-jcasc` Helm chart from your local repository.

## Features

-   **Automated Cluster Creation**: Provisions a Minikube cluster with the Docker driver.
-   **Addons Enabled**: Automatically enables `storage-provisioner`, `metrics-server`, and `ingress`.
-   **Helm Deployment**: Deploys the local `jenkins-jcasc` Helm chart.
-   **Dynamic Image Tag**: Accepts the custom-built Jenkins image tag as an input variable.

---

## 🚀 Deployment Workflow

Follow these steps to build your Jenkins image and deploy it with Terraform.

### 1. Prerequisites

-   **Terraform**: Install Guide
-   **Docker**: Install Guide
-   **kubectl**: Install Guide
-   **Minikube**: Install Guide

### 2. Build the Jenkins Docker Image

Before running Terraform, you must build the custom Jenkins Docker image. The `build.sh` script is located in `k8s-app/jenkins-jcasc/`.

```bash
# From the repository root, navigate to the Jenkins image build directory
cd k8s-app/jenkins-jcasc/

# Run the build script
./build.sh
```

The script will output a full image name, like `jenkins-jcasc:20231027-123456`. **Copy the tag** (e.g., `20231027-123456`) for the next step.

### 3. Deploy with Terraform

Now, navigate to this directory (`k8s-app/terraform/jenkins-jcasc/`) and run Terraform, passing the image tag you just copied.

```bash
# From the repository root, navigate to this terraform directory
cd k8s-app/terraform/jenkins-jcasc/

# Initialize Terraform providers (only needs to be done once)
terraform init

# Apply the configuration
# Replace YOUR_IMAGE_TAG with the tag from the previous step
terraform apply -var="jenkins_image_tag=YOUR_IMAGE_TAG"
```

Terraform will now create the Minikube cluster and deploy Jenkins. This may take several minutes.

### 4. Access Jenkins

Once `terraform apply` is complete, it will display outputs including the Jenkins URL and a command to get the admin password.

1.  **Get the URL**: Check the `jenkins_url` output.
2.  **Get the Password**: Run the command from the `jenkins_admin_password_command` output.
3.  **Login**: Open the URL in your browser and log in with user `admin` and the retrieved password.

---

## 🧹 Cleanup

To tear down the entire environment (Minikube cluster and all deployed resources), run the destroy command from this directory.

```bash
# From the k8s-app/terraform/jenkins-jcasc/ directory
terraform destroy -var="jenkins_image_tag=any-tag"
```

> **Note:** You must provide the variable on destroy, but its value doesn't matter for the destroy operation.