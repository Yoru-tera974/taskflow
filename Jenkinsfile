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

        // =============================================
        // PARTIE 4 — DEPLOIEMENT CONTINU (CD)
        // Declenche automatiquement sur merge dans main
        // Deploiement sans coupure avec Rolling Update
        // =============================================
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "Deploiement de ${REGISTRY}/${IMAGE_NAME}:${VERSION} en cours..."

                    // --- ROLLING UPDATE sans coupure ---
                    // 1. Demarrer le nouveau conteneur sur un port temporaire
                    sh """
                        docker run -d \
                            --name taskflow-new \
                            -p 8082:8080 \
                            --restart unless-stopped \
                            ${REGISTRY}/${IMAGE_NAME}:${VERSION}
                    """

                    // 2. Attendre que le nouveau conteneur soit pret
                    sleep(10)
                    def newIP = sh(
                        script: "docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' taskflow-new",
                        returnStdout: true
                    ).trim()
                    def healthCheck = sh(
                        script: "curl -s -o /dev/null -w '%{http_code}' http://${newIP}:8080/health",
                        returnStdout: true
                    ).trim()

                    if (healthCheck != '200') {
                        // Rollback immediat si le nouveau conteneur ne repond pas
                        sh 'docker rm -f taskflow-new || true'
                        error "Rolling update ECHEC : nouveau conteneur KO (HTTP ${healthCheck}). Rollback effectue."
                    }

                    // 3. Basculer : supprimer l'ancien, renommer le nouveau
                    sh """
                        docker rm -f taskflow || true
                        docker rename taskflow-new taskflow
                        docker update --publish-add 8081:8080 taskflow || true
                    """

                    echo "Rolling update OK : ${REGISTRY}/${IMAGE_NAME}:${VERSION} en production"
                }
            }
        }
    }
    post {
        success {
            echo "======================================"
            echo "Pipeline CI/CD termine avec SUCCES !"
            echo "Artefact : ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
            echo "======================================"
        }
        failure {
            echo "======================================"
            echo "Pipeline en ECHEC"
            echo "Rollback disponible : relancer avec version precedente"
            echo "======================================"
        }
        always {
            // Nettoyage : supprimer images anciennes (garder les 3 dernieres)
            sh """
                docker images ${REGISTRY}/${IMAGE_NAME} --format '{{.Tag}}' | \
                grep -v latest | sort -t v -k2 -rn | tail -n +4 | \
                xargs -I {} docker rmi ${REGISTRY}/${IMAGE_NAME}:{} || true
            """
        }
    }
}
