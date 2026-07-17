FROM jenkins/jenkins:2.516.3-lts-jdk21

USER root

# Install useful packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    vim \
    unzip \
    groovy \
    && rm -rf /var/lib/apt/lists/*

USER jenkins

# Copy plugin list
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt

# Install plugins
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Copy initial JCasC configuration
COPY casc_configs /usr/share/jenkins/ref/casc_configs

# Copy seeding jobs (optional) --> move to seperate repo
# COPY jobs /usr/share/jenkins/ref/jobs

# Init Groovy Scripts
COPY init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/

# Environment variable to enable JCasC
# ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/casc_configs