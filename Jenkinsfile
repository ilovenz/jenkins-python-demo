pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 20, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '10'))
    disableConcurrentBuilds()
  }

  environment {
    IMAGE_NAME = 'alexleesz319/jenkins-python-demo'
    IMAGE_TAG  = "${env.BUILD_NUMBER}"
    DOCKER_BUILDKIT = '0'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'ls -la'
      }
    }

    stage('Test') {
      steps {
        sh '''
          docker build --target test -t "$IMAGE_NAME:test" .
          docker run --rm "$IMAGE_NAME:test"
        '''
      }
    }

    stage('Build image') {
      steps {
        sh '''
          docker build -t "$IMAGE_NAME:$IMAGE_TAG" -t "$IMAGE_NAME:staging" .
        '''
      }
    }

    stage('Push image') {
      when {
        anyOf {
          branch 'main'
          branch 'master'
        }
      }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push "$IMAGE_NAME:$IMAGE_TAG"
            docker push "$IMAGE_NAME:staging"
          '''
        }
      }
    }

    stage('Deploy staging') {
      when {
        anyOf {
          branch 'main'
          branch 'master'
        }
      }
      steps {
        sh '''
          IMAGE="$IMAGE_NAME:staging" docker compose -f docker-compose.staging.yml up -d
          sleep 3
          curl -fsS http://host.docker.internal:5001/health || curl -fsS http://172.17.0.1:5001/health
        '''
      }
    }

    stage('Approve production') {
      when {
        anyOf {
          branch 'main'
          branch 'master'
        }
      }
      steps {
        input message: '确认部署到生产？学习阶段点 Abort 即可。', ok: 'Deploy'
      }
    }

    stage('Deploy production') {
      when {
        anyOf {
          branch 'main'
          branch 'master'
        }
      }
      steps {
        echo "学习阶段只模拟生产发布"
      }
    }
  }

  post {
    always {
      sh 'docker logout || true'
    }
    success {
      echo '构建成功'
    }
    failure {
      echo '构建失败，打开 Console Output 从第一个红色 stage 往上看。'
    }
  }
}
