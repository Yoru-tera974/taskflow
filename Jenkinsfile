pipeline {
    agent any
    tools {
        nodejs "node18"
    }
    environment {
        IMAGE_NAME = 'taskflow'
        REGISTRY   = 'localhost:5000'
        VERSION    = "v${env.BUILD_NUMBER}"
    }
    stages {
        stage('Install') {
            steps {
                sh '''
                    export NPM_CACHE=/var/jenkins_home/.npm
                    npm install --cache $NPM_CACHE
                '''
                echo "Dependances installees avec succes"
            }
        }
        stage('Test') {
            steps {
                sh 'npm test -- --coverage'
            }
        }
        stage('Security Scan') {
            steps {
                sh 'npm audit --audit-level=high'
                echo "Scan securite OK"
            }
        }
        stage('Docker Build') {
            steps {
                sh "docker build -t ${REGISTRY}/${IMAGE_NAME}:${VERSION} ."
                sh "docker tag ${REGISTRY}/${IMAGE_NAME}:${VERSION} ${REGISTRY}/${IMAGE_NAME}:latest"
                echo "Image construite : ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
            }
        }
        stage('Docker Push') {
            steps {
                sh "docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
                sh "docker push ${REGISTRY}/${IMAGE_NAME}:latest"
            }
        }
        stage('Run Container') {
            steps {
                sh '''
                    docker rm -f taskflow || true
                    docker run -d --name taskflow -p 8081:8080 ${REGISTRY}/taskflow:${VERSION}
                '''
            }
        }
        stage('Smoke Test') {
            steps {
                script {
                    sleep(5)
                    def taskflowIP = sh(
                        script: "docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' taskflow",
                        returnStdout: true
                    ).trim()
                    echo "IP taskflow : ${taskflowIP}"
                    def response = sh(
                        script: "curl -s -o /dev/null -w '%{http_code}' http://${taskflowIP}:8080/health",
                        returnStdout: true
                    ).trim()
                    if (response != '200') {
                        error "Smoke test ECHEC : HTTP ${response}"
                    }
                    echo "Smoke test OK : HTTP 200"
                }
            }
        }
    }  // <- accolade manquante qui fermait stages
    post {
        success {
            echo "======================================"
            echo "Pipeline CI termine avec SUCCES !"
            echo "Artefact : ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
            echo "======================================"
        }
        failure {
            echo "======================================"
            echo "Pipeline en ECHEC"
            echo "======================================"
        }
    }
}
