pipelineJob('Mode-Seed-Job-2') {

    description('Mode seeding job for Mode 2')

    definition {

        cps {

            script("""
pipeline {

    agent any

    stages {

        stage('Mode 2 Checkout') {
            steps {
                echo 'Checking out source code for Mode 2'
            }
        }

        stage('Mode 2 Build') {
            steps {
                echo 'Building application for Mode 2'
            }
        }

        stage('Mode 2 Test') {
            steps {
                echo 'Running Mode 2 tests'
            }
        }

        stage('Mode 2 Deploy') {
            steps {
                echo 'Deploying application for Mode 2'
            }
        }
    }
}
""")

            sandbox()
        }
    }
}