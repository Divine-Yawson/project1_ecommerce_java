pipeline {
    agent any

    environment {
        IMAGE_NAME = 'ecommerce-backend'
        DOCKER_REGISTRY = 'divine2200'  // Docker Hub username only
        PATH = "/usr/share/maven/bin:/usr/bin:/bin:/usr/local/bin:$PATH"
        MAVEN_HOME = '/usr/share/maven'
    }

    stages {
        stage('Verify Tools') {
            steps {
                sh '''
                    echo "=== Tool Versions ==="
                    echo "Maven: $(mvn --version || echo 'Maven not found!')"
                    echo "Git: $(git --version || echo 'Git not found!')"
                    echo "Docker: $(docker --version || echo 'Docker not found!')"
                    echo "kubectl: $(kubectl version --client=true --short || echo 'kubectl not found!')"
                    echo "AWS CLI: $(aws --version || echo 'AWS CLI not found!')"
                    echo "PATH: $PATH"
                '''
            }
        }

        stage('Clone') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/dev']],
                    extensions: [],
                    userRemoteConfigs: [[
                        credentialsId: 'github-creds',
                        url: 'https://github.com/Divine-Yawson/project1_ecommerce_java.git'
                    ]]
                ])
                
                // Add directory verification
                sh '''
                    echo "Repository contents:"
                    ls -lR
                '''
            }
        }

        stage('Build with Maven') {
            steps {
                dir('backend') {
                    sh '''
                        echo "Current directory: $(pwd)"
                        echo "Building with Maven..."
                        mvn clean package -DskipTests
                    '''
                }
            }
            post {
                success {
                    archiveArtifacts 'backend/target/*.jar'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('backend') {
                    script {
                        def COMMIT_SHA = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                        env.COMMIT_SHA = COMMIT_SHA

                        sh """
                            docker build \
                                -t $DOCKER_REGISTRY/$IMAGE_NAME:latest \
                                -t $DOCKER_REGISTRY/$IMAGE_NAME:$COMMIT_SHA .
                        """
                    }
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-credentials',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push $DOCKER_REGISTRY/$IMAGE_NAME:latest
                        docker push $DOCKER_REGISTRY/$IMAGE_NAME:$COMMIT_SHA
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([[ 
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    script {
                        // Verify k8s directory exists
                        def k8sExists = fileExists 'k8s/deployment.yaml'
                        if (!k8sExists) {
                            error "Kubernetes manifests not found in k8s/ directory"
                        }
                        
                        dir('k8s') {
                            sh '''
                                echo "=== Current k8s directory contents ==="
                                ls -l
                                
                                echo "=== Configuring kubectl ==="
                                aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster
                                
                                echo "=== Updating deployment image ==="
                                sed -i "s|image:.*|image: $DOCKER_REGISTRY/$IMAGE_NAME:$COMMIT_SHA|" deployment.yaml
                                
                                echo "=== Applying manifests ==="
                                kubectl apply -f deployment.yaml || echo "Deployment failed"
                                kubectl apply -f service.yaml || echo "Service failed"
                                kubectl apply -f ingress.yaml || echo "Ingress failed"
                                
                                echo "=== Verifying deployment ==="
                                kubectl rollout status deployment/ecommerce-backend --timeout=3m || {
                                    echo "Deployment failed"
                                    kubectl describe deployment ecommerce-backend
                                    kubectl logs -l app=ecommerce-backend --all-containers
                                    exit 1
                                }
                            '''
                        }
                    }
                }
            }
        }
    }

    post {
       post {
    always {
        cleanWs(cleanWhenAborted: true, cleanWhenFailure: true, cleanWhenNotBuilt: true, cleanWhenUnstable: true)
    }
    success {
        script {
            try {
                slackSend(color: 'good', message: "SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'")
            } catch (Exception e) {
                echo "Slack notification failed: ${e.getMessage()}"
            }
        }
    }
    failure {
        script {
            try {
                slackSend(color: 'danger', message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'")
            } catch (Exception e) {
                echo "Slack notification failed: ${e.getMessage()}"
            }
        }
    }
}
}