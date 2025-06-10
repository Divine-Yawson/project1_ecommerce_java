pipeline {
    agent any
    
    environment {
        IMAGE_NAME = 'ecommerce-backend'
        DOCKER_REGISTRY = 'divine2200'  // Fixed: this should be your Docker Hub username
        PATH = "/usr/share/maven/bin:/usr/bin:/bin:/usr/local/bin:$PATH"
        MAVEN_HOME = '/usr/share/maven'
    }

    stages {
        stage('Verify Tools') {
            steps {
                sh '''
                    echo "=== Tool Versions ==="
                    mvn --version || echo 'Maven not found!'
                    git --version || echo 'Git not found!'
                    docker --version || echo 'Docker not found!'
                    kubectl version --client=true --short || echo 'kubectl not found!'
                    aws --version || echo 'AWS CLI not found!'
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
            }
        }

        stage('Build with Maven') {
            steps {
                dir('backend') {
                    sh '''
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
                        COMMIT_SHA = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
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
                    credentialsId: 'docker-credentials', // or correct this to your actual Jenkins credential ID
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
                withCredentials([[ // Uses IAM user credentials
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    dir('k8s') {
                        sh '''
                            aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster

                            # Replace image tag in YAML
                            sed -i "s|image:.*|image: $DOCKER_REGISTRY/$IMAGE_NAME:$COMMIT_SHA|" deployment.yaml

                            kubectl apply -f deployment.yaml
                            kubectl apply -f service.yaml
                            kubectl apply -f ingress.yaml

                            kubectl rollout status deployment/ecommerce-backend
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            slackSend(color: 'good', message: "SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'")
        }
        failure {
            slackSend(color: 'danger', message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'")
        }
    }
}
