// ============================================================
// Jenkinsfile — Pipeline CI TaskFlow
// TP Fil Rouge CI/CD — Noel Evan
// Cours : Infrastructure as Code — Tristan BASTIEN
// ============================================================

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

        // STAGE 1 — Installation des dépendances Node.js
        stage('Install') {
            steps {
                sh '''
                    export NPM_CACHE=/var/jenkins_home/.npm
                    npm install --cache $NPM_CACHE
                '''
                echo "Dépendances installées avec succès"
            }
        }

        // STAGE 2 — Tests unitaires
        stage('Test') {
            steps {
                sh 'npm test -- --coverage'
            }
        }

        // STAGE 3 — Scan de sécurité
        stage('Security Scan') {
            steps {
                sh 'npm audit --audit-level=high'
                echo "Scan sécurité OK"
            }
        }

        // STAGE 4 — Construction de l'image Docker
        stage('Docker Build') {
            steps {
                sh "docker build -t ${REGISTRY}/${IMAGE_NAME}:${VERSION} ."
                sh "docker tag ${REGISTRY}/${IMAGE_NAME}:${VERSION} ${REGISTRY}/${IMAGE_NAME}:latest"
                echo "Image construite : ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
            }
        }

        // STAGE 5 — Push dans le registry local
        stage('Docker Push') {
            steps {
                sh "docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
                sh "docker push ${REGISTRY}/${IMAGE_NAME}:latest"
            }
        }

        // STAGE 6 — Lancement du conteneur pour le smoke test
        stage('Run Container') {
            steps {
                sh '''
                    docker rm -f taskflow || true
                    docker run -d --name taskflow -p 8081:8080 ${REGISTRY}/taskflow:${VERSION}
                '''
            }
        }

        // STAGE 7 — Smoke test
        stage('Smoke Test') {
            steps {
                script {
                    sleep(5)
                    def response = sh(
                        script: 'curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/health',
                        returnStdout: true
                    ).trim()

                    if (response != '200') {
                        error "Smoke test ÉCHEC : HTTP ${response}"
                    }

                    echo "Smoke test OK : HTTP 200"
                }
            }
        }
    }

    post {
        success {
            echo "======================================"
            echo "Pipeline CI terminé avec SUCCÈS !"
            echo "Artefact : ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
            echo "======================================"
        }
        failure {
            echo "======================================"
            echo "Pipeline en ÉCHEC"
            echo "======================================"
        }
    }
}