---
name: jenkins-pipeline
description: 使用 Jenkins 设置和维护 CI/CD 流水线，自动化测试、构建和部署。当用户提到 Jenkins、配置 Jenkinsfile、设置 Jenkins 流水线、Jenkins 任务配置、Jenkins 多分支流水线、Jenkins 与 Docker/Kubernetes 集成、Jenkins 共享库、Jenkins 自动化部署、Jenkins 构建缓存、Jenkins 蓝绿部署或 Jenkins 回滚策略时使用此 skill。即使没有明确提及"Jenkins"，只要涉及 Jenkins 相关的 CI/CD 场景，也应使用此 skill。
---

# Jenkins 流水线 - 自动化构建、测试和部署

## 何时使用此 Skill

- 设置 Jenkins 流水线
- 编写 Jenkinsfile
- 配置多分支流水线
- 实现 Jenkins 共享库
- 配置 Jenkins 与 Docker/Kubernetes 集成
- 设置 Jenkins 构建缓存
- 实现蓝绿或金丝雀部署
- 配置自动回滚策略
- 设置 Jenkins 安全和权限管理
- 配置 Jenkins 通知（Slack、邮件等）

---

## 核心原则

1. **一切皆自动化** - 手动步骤容易出错
2. **快速失败** - 在流水线早期捕获问题
3. **先测试后部署** - 永不部署未测试的代码
4. **可重现构建** - 相同输入 = 相同输出
5. **零停机部署** - 用户无感知

---

## Jenkinsfile 基础

### 1. 声明式流水线

```groovy
// Jenkinsfile
pipeline {
    agent any

    environment {
        NODE_VERSION = '20'
    }

    stages {
        stage('检出代码') {
            steps {
                checkout scm
            }
        }

        stage('安装依赖') {
            steps {
                sh 'npm ci'
            }
        }

        stage('代码检查') {
            parallel {
                stage('Linter') {
                    steps {
                        sh 'npm run lint'
                    }
                }
                stage('类型检查') {
                    steps {
                        sh 'npm run typecheck'
                    }
                }
            }
        }

        stage('单元测试') {
            steps {
                sh 'npm test -- --coverage'
            }
            post {
                always {
                    junit 'coverage/junit.xml'
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'coverage',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }

        stage('构建') {
            steps {
                sh 'npm run build'
            }
        }
    }

    post {
        success {
            echo '构建成功！'
        }
        failure {
            echo '构建失败！'
        }
    }
}
```

### 2. 多分支流水线

```groovy
// Jenkinsfile - 支持多分支
pipeline {
    agent none

    stages {
        stage('构建') {
            matrix {
                axes {
                    axis {
                        name 'NODE_VERSION'
                        values '18', '20', '21'
                    }
                    axis {
                        name 'OS'
                        values 'linux', 'windows'
                    }
                }
                agent {
                    label "${OS}"
                }
                stages {
                    stage('安装和测试') {
                        steps {
                            sh "nvm use ${NODE_VERSION}"
                            sh 'npm ci'
                            sh 'npm test'
                        }
                    }
                }
            }
        }
    }
}
```

### 3. 带参数的流水线

```groovy
pipeline {
    agent any

    parameters {
        choice(
            name: 'DEPLOY_ENV',
            choices: ['staging', 'production'],
            description: '选择部署环境'
        )
        booleanParam(
            name: 'RUN_E2E',
            defaultValue: true,
            description: '是否运行端到端测试'
        )
        string(
            name: 'VERSION',
            defaultValue: '',
            description: '指定版本号（留空则自动生成）'
        )
    }

    stages {
        stage('部署') {
            when {
                expression { params.DEPLOY_ENV == 'production' }
            }
            input {
                message "确认部署到生产环境？"
                ok "确认部署"
                submitter "admin,devops"
            }
            steps {
                sh "deploy.sh ${params.DEPLOY_ENV}"
            }
        }
    }
}
```

---

## Jenkins 与 Docker 集成

### 1. Docker 构建和推送

```groovy
pipeline {
    agent {
        docker {
            image 'node:20'
            args '-p 3000:3000'
        }
    }

    environment {
        IMAGE_NAME = 'myorg/myapp'
        DOCKER_CREDS = credentials('docker-hub')
    }

    stages {
        stage('构建镜像') {
            steps {
                script {
                    docker.withRegistry('', 'docker-hub') {
                        def app = docker.build("${IMAGE_NAME}:${BUILD_NUMBER}")
                        app.push()
                        app.push('latest')
                    }
                }
            }
        }
    }
}
```

### 2. 使用 Docker Compose

```groovy
pipeline {
    agent any

    stages {
        stage('启动服务') {
            steps {
                sh 'docker-compose -f docker-compose.test.yml up -d'
            }
        }

        stage('运行测试') {
            steps {
                sh 'npm run test:e2e'
            }
        }

        stage('清理') {
            steps {
                sh 'docker-compose -f docker-compose.test.yml down -v'
            }
            post {
                always {
                    sh 'docker-compose -f docker-compose.test.yml down -v --remove-orphans'
                }
            }
        }
    }
}
```

---

## Jenkins 与 Kubernetes 集成

### 1. Kubernetes Pod 模板

```groovy
pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: node
    image: node:20
    command:
    - cat
    tty: true
  - name: docker
    image: docker:latest
    command:
    - cat
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
        }
    }

    stages {
        stage('测试') {
            steps {
                container('node') {
                    sh 'npm ci && npm test'
                }
            }
        }

        stage('构建镜像') {
            steps {
                container('docker') {
                    sh 'docker build -t myapp:${BUILD_NUMBER} .'
                    sh 'docker push myapp:${BUILD_NUMBER}'
                }
            }
        }
    }
}
```

### 2. Helm 部署

```groovy
pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: helm
    image: alpine/helm:latest
    command: [cat]
    tty: true
'''
        }
    }

    environment {
        KUBECONFIG = credentials('kubeconfig')
    }

    stages {
        stage('部署') {
            steps {
                container('helm') {
                    sh '''
                        helm upgrade --install myapp ./chart \
                            --namespace production \
                            --set image.tag=${BUILD_NUMBER} \
                            --wait --timeout 5m
                    '''
                }
            }
        }
    }
}
```

---

## 部署策略

### 1. 蓝绿部署

```groovy
pipeline {
    agent any

    stages {
        stage('部署到蓝环境') {
            steps {
                sh '''
                    kubectl apply -f k8s/blue-deployment.yaml
                    kubectl rollout status deployment/myapp-blue
                '''
            }
        }

        stage('健康检查') {
            steps {
                sh '''
                    # 等待蓝环境就绪
                    kubectl wait --for=condition=ready pod -l app=myapp,color=blue --timeout=300s

                    # 运行冒烟测试
                    npm run test:smoke -- --url=https://blue.myapp.internal
                '''
            }
        }

        stage('切换流量') {
            input {
                message "确认切换到蓝环境？"
            }
            steps {
                sh '''
                    # 更新 Service 指向蓝环境
                    kubectl patch service myapp -p '{"spec":{"selector":{"color":"blue"}}}'
                '''
            }
        }

        stage('清理绿环境') {
            steps {
                sh 'kubectl delete deployment myapp-green --ignore-not-found=true'
            }
        }
    }
}
```

### 2. 金丝雀部署

```groovy
pipeline {
    agent any

    stages {
        stage('金丝雀部署 (10%)') {
            steps {
                sh '''
                    # 部署 1 个金丝雀 Pod
                    kubectl apply -f k8s/canary-deployment.yaml

                    # 设置 10% 流量到金丝雀
                    kubectl patch virtualservice myapp --type=merge -p '
                    {
                        "spec": {
                            "http": [{
                                "route": [
                                    {"destination": {"host": "myapp", "subset": "stable"}, "weight": 90},
                                    {"destination": {"host": "myapp", "subset": "canary"}, "weight": 10}
                                ]
                            }]
                        }
                    }'
                '''
            }
        }

        stage('监控金丝雀') {
            steps {
                script {
                    // 监控 10 分钟
                    sleep(time: 10, unit: 'MINUTES')

                    // 检查错误率
                    def errorRate = sh(
                        script: 'get-error-rate.sh canary',
                        returnStdout: true
                    ).trim()

                    if (errorRate.toInteger() > 5) {
                        error "金丝雀错误率过高: ${errorRate}%"
                    }
                }
            }
        }

        stage('全量部署') {
            steps {
                sh '''
                    # 扩展到完整副本数
                    kubectl scale deployment myapp --replicas=5

                    # 100% 流量切换
                    kubectl patch virtualservice myapp --type=merge -p '
                    {
                        "spec": {
                            "http": [{
                                "route": [
                                    {"destination": {"host": "myapp", "subset": "stable"}, "weight": 100}
                                ]
                            }]
                        }
                    }'
                '''
            }
        }
    }

    post {
        failure {
            sh '''
                # 自动回滚
                kubectl rollout undo deployment/myapp
                echo "已自动回滚"
            '''
        }
    }
}
```

---

## Jenkins 共享库

### 1. 创建共享库

```groovy
// vars/deployToK8s.groovy
def call(Map config) {
    pipeline {
        agent any

        environment {
            KUBECONFIG = credentials('kubeconfig')
        }

        stages {
            stage('部署') {
                steps {
                    sh """
                        kubectl set image deployment/${config.deploymentName} \
                            ${config.containerName}=${config.image}:${config.tag} \
                            --namespace ${config.namespace ?: 'default'}
                    """
                }
            }

            stage('健康检查') {
                steps {
                    sh """
                        kubectl rollout status deployment/${config.deploymentName} \
                            --namespace ${config.namespace ?: 'default'} \
                            --timeout=5m
                    """
                }
            }
        }
    }
}
```

### 2. 使用共享库

```groovy
// Jenkinsfile
@Library('my-shared-lib@main') _

deployToK8s(
    deploymentName: 'myapp',
    containerName: 'app',
    image: 'myorg/myapp',
    tag: env.BUILD_NUMBER,
    namespace: 'production'
)
```

---

## 最佳实践

### 1. 构建缓存

```groovy
pipeline {
    agent any

    stages {
        stage('缓存依赖') {
            steps {
                script {
                    // 使用 Jenkins 缓存
                    cache(maxCacheSize: 250, caches: [
                        [$class: 'ArbitraryFileCache', path: 'node_modules', cacheValidityDecidingFile: 'package-lock.json']
                    ]) {
                        sh 'npm ci'
                    }
                }
            }
        }
    }
}
```

### 2. 凭证管理

```groovy
pipeline {
    agent any

    environment {
        // 从 Jenkins 凭证存储获取
        DOCKER_CREDS = credentials('docker-hub')
        AWS_ACCESS_KEY = credentials('aws-access-key')
        // 使用 withCredentials 处理敏感数据
    }

    stages {
        stage('部署') {
            steps {
                withCredentials([
                    string(credentialsId: 'api-key', variable: 'API_KEY'),
                    file(credentialsId: 'ssh-key', variable: 'SSH_KEY')
                ]) {
                    sh 'deploy.sh'
                }
            }
        }
    }
}
```

### 3. 质量门禁

```groovy
pipeline {
    agent any

    stages {
        stage('代码质量') {
            steps {
                script {
                    // 代码覆盖率检查
                    def coverage = sh(
                        script: 'npm test -- --coverage --json',
                        returnStdout: true
                    )

                    def coveragePercent = parseCoverage(coverage)
                    if (coveragePercent < 80) {
                        error "代码覆盖率 ${coveragePercent}% 低于阈值 80%"
                    }

                    // SonarQube 分析
                    withSonarQubeEnv('my-sonar') {
                        sh 'sonar-scanner'
                    }
                }
            }
        }

        stage('质量门禁检查') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
    }
}
```

### 4. 通知配置

```groovy
pipeline {
    agent any

    post {
        success {
            slackSend(
                channel: '#deployments',
                color: 'good',
                message: "构建成功: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            )
        }

        failure {
            slackSend(
                channel: '#alerts',
                color: 'danger',
                message: """
                构建失败: ${env.JOB_NAME} #${env.BUILD_NUMBER}
                查看: ${env.BUILD_URL}
                """
            )

            emailext(
                subject: "构建失败: ${env.JOB_NAME}",
                body: """
                构建失败详情:
                - 任务: ${env.JOB_NAME}
                - 编号: ${env.BUILD_NUMBER}
                - 链接: ${env.BUILD_URL}
                """,
                to: 'team@example.com'
            )
        }
    }
}
```

---

## 流水线检查清单

```
构建流水线:
□ 每次提交自动触发
□ 运行 Lint 和类型检查
□ 执行所有测试
□ 生成代码覆盖率报告
□ 构建生产制品
□ 缓存依赖以加速

质量门禁:
□ 最低代码覆盖率阈值（如 80%）
□ 无关键漏洞（npm audit）
□ 代码质量检查（SonarQube）
□ 无 Lint 错误
□ 所有测试通过

部署:
□ 自动部署到测试环境
□ 生产环境需人工审批
□ 流量切换前健康检查
□ 具备回滚能力
□ 零停机策略（蓝绿、金丝雀、滚动）

安全:
□ 凭证安全存储（Jenkins Credentials）
□ 依赖扫描
□ 容器漏洞扫描
□ SAST/DAST 安全扫描

监控:
□ 构建状态通知（Slack、邮件）
□ 部署通知
□ 部署后错误率监控
□ 自动回滚机制
□ 审计日志
```

---

**记住**: 优秀的 Jenkins 流水线应该快速、可靠，让开发者有信心频繁部署。