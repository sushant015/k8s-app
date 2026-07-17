pipelineJob('Mode-Seed-Job-1') {

    description('Mode seeding job for Mode 1')

    definition {

        cps {

            script("""
pipeline {

    agent any

    stages {

        stage('Mode 1 Checkout') {
            steps {
                echo 'Checking out source code for Mode 1'
            }
        }

        stage('Mode 1 Build') {
            steps {
                echo 'Building application for Mode 1'
            }
        }

        stage('Mode 1 Test') {
            steps {
                echo 'Running Mode 1 tests'
            }
        }

        stage('Mode 1 Deploy') {
            steps {
                echo 'Deploying application for Mode 1'
            }
        }
    }
}
""")

            sandbox()
        }
    }
}