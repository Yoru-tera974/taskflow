// ============================================================
// Jenkinsfile — Pipeline CI TaskFlow
// TP Fil Rouge CI/CD — Noel Evan
// Cours : Infrastructure as Code — Tristan BASTIEN
// ============================================================

pipeline {
    agent any

    environment {
        IMAGE_NAME = 'taskflow'
        REGISTRY   = 'localhost:5000'
        VERSION    = "v${env.BUILD_NUMBER}"
    }

    stages {

        // STAGE 1 — Récupération du code source
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/votre-user/taskflow.git'
                echo "Code récupéré — branche main"
            }
        }

        // STAGE 2 — Installation des dépendances Node.js
        stage('Install') {
            steps {
                sh '''
                    export NPM_CACHE=/var/jenkins_home/.npm
                    npm install --cache $NPM_CACHE
                '''
                echo "Dépendances installées avec succès"
            }
        }

        // STAGE 3 — Tests unitaires
        // Si les tests échouent : pipeline STOP + mail d'alerte
        stage('Test') {
            steps {
                sh 'npm test -- --coverage'
            }
            post {
                failure {
                    echo 'ÉCHEC DES TESTS — pipeline arrêté, aucune image produite'
                    mail to: 'evan@taskflow.fr',
                         subject: "Build #${BUILD_NUMBER} — TESTS KO",
                         body: "Des tests ont échoué sur le build #${BUILD_NUMBER}. Consulter Jenkins : ${env.BUILD_URL}"
                }
            }
        }

        // STAGE 4 — Scan de sécurité des dépendances
        stage('Security Scan') {
            steps {
                sh 'npm audit --audit-level=high'
                echo "Scan sécurité OK — aucune CVE critique"
            }
        }

        // STAGE 5 — Construction de l'image Docker versionnée
        stage('Docker Build') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${VERSION} ."
                sh "docker tag ${IMAGE_NAME}:${VERSION} ${IMAGE_NAME}:latest"
                echo "Image construite : ${IMAGE_NAME}:${VERSION}"
            }
        }

        // STAGE 6 — Push dans le registry local
        stage('Docker Push') {
            steps {
                sh "docker tag ${IMAGE_NAME}:${VERSION} ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
                sh "docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
                sh "docker push ${REGISTRY}/${IMAGE_NAME}:latest"
                echo "Image poussée : ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
            }
        }

        // STAGE 7 — Smoke test post-déploiement (BONUS)
        stage('Smoke Test') {
            steps {
                script {
                    sleep(5)
                    def response = sh(
                        script: 'curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health',
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
            echo "Artefact : ${IMAGE_NAME}:${VERSION}"
            echo "======================================"
        }
        failure {
            echo "======================================"
            echo "Pipeline en ÉCHEC — aucun artefact produit"
            echo "Consulter les logs pour diagnostiquer"
            echo "======================================"
        }
    }
}
