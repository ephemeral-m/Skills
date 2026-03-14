---
name: jenkins-pipeline
description: 使用 Jenkins 设置和维护 CI/CD 流水线，自动化测试、构建和部署。当用户提到 Jenkins、Jenkinsfile、CI/CD 流水线、自动化构建、Docker/Kubernetes 部署、蓝绿部署、金丝雀发布时使用此 skill。
---

# Jenkins 流水线

自动化构建、测试和部署。

## 核心原则

1. **一切皆自动化** - 手动步骤容易出错
2. **快速失败** - 在流水线早期捕获问题
3. **先测试后部署** - 永不部署未测试的代码
4. **可重现构建** - 相同输入 = 相同输出

## Jenkinsfile 基础

```groovy
pipeline {
    agent any

    stages {
        stage('检出代码') {
            steps { checkout scm }
        }

        stage('代码检查') {
            parallel {
                stage('Linter') { steps { sh 'npm run lint' } }
                stage('类型检查') { steps { sh 'npm run typecheck' } }
            }
        }

        stage('单元测试') {
            steps { sh 'npm test -- --coverage' }
            post {
                always {
                    junit 'coverage/junit.xml'
                    publishHTML([allowMissing: false, reportDir: 'coverage', reportFiles: 'index.html', reportName: 'Coverage Report'])
                }
            }
        }

        stage('构建') {
            steps { sh 'npm run build' }
        }
    }
}
```

## Docker 集成

```groovy
pipeline {
    agent { docker { image 'node:20' } }
    environment {
        IMAGE_NAME = 'myorg/myapp'
    }
    stages {
        stage('构建镜像') {
            steps {
                script {
                    docker.withRegistry('', 'docker-hub') {
                        def app = docker.build("${IMAGE_NAME}:${BUILD_NUMBER}")
                        app.push()
                    }
                }
            }
        }
    }
}
```

## Kubernetes 集成

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
    command: [cat]
    tty: true
'''
        }
    }
    stages {
        stage('测试') {
            steps {
                container('node') { sh 'npm ci && npm test' }
            }
        }
    }
}
```

## 部署策略

### 蓝绿部署

```groovy
stage('切换流量') {
    input { message "确认切换到蓝环境？" }
    steps {
        sh 'kubectl patch service myapp -p \'{"spec":{"selector":{"color":"blue"}}}\''
    }
}
```

### 金丝雀部署

```groovy
stage('金丝雀 (10%)') {
    steps {
        sh 'kubectl patch virtualservice myapp --type=merge -p \'{"spec":{"http":[{"route":[{"destination":{"host":"myapp","subset":"stable"},"weight":90},{"destination":{"host":"myapp","subset":"canary"},"weight":10}]}]}}\''
    }
}
```

## 最佳实践

| 实践 | 说明 |
|------|------|
| 凭证管理 | 使用 Jenkins Credentials 存储 |
| 构建缓存 | 缓存依赖加速构建 |
| 质量门禁 | 代码覆盖率阈值、SonarQube |
| 通知 | Slack/邮件通知构建状态 |

## 流水线检查清单

```
构建:
□ 每次提交自动触发
□ Lint 和类型检查
□ 单元测试通过
□ 代码覆盖率报告

部署:
□ 自动部署到测试环境
□ 生产环境需人工审批
□ 健康检查
□ 回滚能力
□ 零停机策略
```