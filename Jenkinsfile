// 普通 Pipeline Job（Pipeline script from SCM）通常没有 BRANCH_NAME，
// when { branch 'main' } 会把 Push/Deploy 全部跳过。
// Multibranch 才会设置 BRANCH_NAME。两种 Job 都用这个判断。
def isReleaseBranch() {
  def raw = env.BRANCH_NAME ?: env.GIT_BRANCH ?: ''
  echo "branch check BRANCH_NAME=${env.BRANCH_NAME ?: ''} GIT_BRANCH=${env.GIT_BRANCH ?: ''}"
  if (!raw.trim()) {
    return true
  }
  def b = raw.replaceFirst('^refs/heads/', '').replaceFirst('^origin/', '')
  return b == 'main' || b == 'master'
}

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
        sh '''
          ls -la
          echo "BRANCH_NAME=${BRANCH_NAME:-}"
          echo "GIT_BRANCH=${GIT_BRANCH:-}"
           '''
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
        expression { return isReleaseBranch() }
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
        expression { return isReleaseBranch() }
      }
      steps {
        sh '''
           docker rm -f jenkins-python-demo-staging || true
           IMAGE="$IMAGE_NAME:staging" docker compose -f docker-compose.staging.yml up -d --force-recreate
           sleep 3
           curl -fsS http://host.docker.internal:5001/health || curl -fsS http://172.17.0.1:5001/health
        '''
      }
    }

    stage('Approve production') {
      when {
        expression { return isReleaseBranch() }
      }
      steps {
        input message: '确认部署到生产？学习阶段点 Abort 即可。', ok: 'Deploy'
      }
    }

    stage('Deploy production') {
      when {
        expression { return isReleaseBranch() }
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
