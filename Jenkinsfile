pipeline {
    agent any

    environment {
        IMAGE_NAME = 'ecommerce-backend'
        DOCKER_REGISTRY = 'divine2200/ecommerce-backend'  // Change if you're using ECR
        PATH = "/usr/local/bin:/usr/bin:/bin:$PATH"
    }

    stages {
        stage('Clone') {
            steps {
                checkout scm
            }
        }

        stage('Build with Maven') {
            steps {
                dir('backend') {
                    sh 'mvn clean package -DskipTests'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('backend') {
                    sh "docker build -t $DOCKER_REGISTRY/$IMAGE_NAME:latest ."
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-credentials', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                    sh 'echo $PASSWORD | docker login -u $USERNAME --password-stdin'
                    sh "docker push $DOCKER_REGISTRY/$IMAGE_NAME:latest"
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh '''
                        # Update kubeconfig to access EKS cluster
                        aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster

                        # Deploy Kubernetes manifests
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml
                        kubectl apply -f k8s/ingress.yaml
                    '''
                }
            }
        }
    }
}
