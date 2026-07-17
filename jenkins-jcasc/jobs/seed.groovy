pipelineJob('Sample-Pipeline') {

    description('Pipeline created from Job DSL')

    definition {

        cps {

            script("""
pipeline {

    agent any

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out source code'
            }
        }

        stage('Build') {
            steps {
                echo 'Building application'
            }
        }

        stage('Test') {
            steps {
                echo 'Running tests'
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deploying application'
            }
        }
    }
}
""")

            sandbox()
        }
    }
}