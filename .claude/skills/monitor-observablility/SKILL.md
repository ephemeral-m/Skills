---
name: monitoring-observability
description: 为生产应用实现全面的监控、日志、指标、追踪和告警，确保系统可靠性和快速事件响应。当用户需要设置应用监控、实现结构化日志、创建指标和仪表板、设置告警、实现分布式追踪、监控性能、追踪错误或构建可观测性系统时使用此 skill。
---

# 监控与可观测性 - 系统健康

## 何时使用此 Skill

- 设置应用监控系统
- 实现结构化日志
- 创建指标和性能仪表板
- 为关键问题设置告警
- 实现分布式追踪
- 监控 API 性能和延迟
- 追踪错误率和异常
- 构建应用可观测性
- 设置日志聚合
- 创建 SLO/SLA 监控
- 实现健康检查
- 构建事件检测系统

---

## 三大支柱

| 支柱 | 说明 | 示例 |
|------|------|------|
| **指标** | 时间序列数据 | CPU、内存、请求/秒 |
| **日志** | 带上下文的事件记录 | 错误日志、访问日志 |
| **追踪** | 请求在系统中的流转 | 分布式调用链 |

---

## 示例：请求监控中间件

```typescript
import * as Sentry from '@sentry/node';
import { metrics } from './metrics';

// 请求监控中间件
app.use((req, res, next) => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;

    // 记录请求时长
    metrics.histogram('request_duration', duration, {
      method: req.method,
      route: req.route?.path,
      status: res.statusCode,
    });

    // 记录错误
    if (res.statusCode >= 400) {
      Sentry.captureMessage(`HTTP ${res.statusCode}: ${req.method} ${req.path}`);
    }
  });

  next();
});
```

---

## 结构化日志

```typescript
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: 'my-service' },
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
  ],
});

// 使用示例
logger.info('用户登录', {
  userId: '123',
  ip: '192.168.1.1',
  userAgent: 'Mozilla/5.0...',
});
```

---

## 指标收集

```typescript
import { collectDefaultMetrics, Registry, Counter, Histogram } from 'prom-client';

// 创建注册表
const register = new Registry();

// 默认指标
collectDefaultMetrics({ register });

// 自定义计数器
const requestCounter = new Counter({
  name: 'http_requests_total',
  help: 'HTTP 请求总数',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

// 自定义直方图
const requestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP 请求时长',
  labelNames: ['method', 'route'],
  buckets: [0.1, 0.5, 1, 2, 5],
  registers: [register],
});

// 使用示例
requestCounter.inc({ method: 'GET', route: '/api/users', status: '200' });
requestDuration.observe({ method: 'GET', route: '/api/users' }, 0.5);
```

---

## 健康检查端点

```typescript
app.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    checks: {
      database: await checkDatabase(),
      redis: await checkRedis(),
      externalApi: await checkExternalApi(),
    },
  };

  const allHealthy = Object.values(health.checks).every(c => c.status === 'ok');

  res.status(allHealthy ? 200 : 503).json(health);
});

async function checkDatabase() {
  try {
    await db.query('SELECT 1');
    return { status: 'ok', latency: 5 };
  } catch (error) {
    return { status: 'error', message: error.message };
  }
}
```

---

## 告警配置示例

```yaml
# Prometheus 告警规则
groups:
  - name: application
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "高错误率"
          description: "5xx 错误率超过 10%"

      - alert: HighLatency
        expr: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "高延迟"
          description: "P99 延迟超过 2 秒"

      - alert: ServiceDown
        expr: up{job="my-service"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "服务下线"
          description: "服务实例不可用"
```

---

## 常用工具

| 类别 | 工具 | 用途 |
|------|------|------|
| 指标 | Prometheus | 指标收集和存储 |
| 仪表板 | Grafana | 可视化和仪表板 |
| 日志 | ELK Stack | 日志聚合和分析 |
| 追踪 | Jaeger | 分布式追踪 |
| 错误追踪 | Sentry | 错误监控和报告 |
| APM | Datadog | 全栈监控 |

---

## 参考资源

- [可观测性指南](https://www.honeycomb.io/what-is-observability)
- [Grafana 文档](https://grafana.com/)
- [Sentry 文档](https://sentry.io/)
- [Prometheus 文档](https://prometheus.io/docs/)
- [OpenTelemetry](https://opentelemetry.io/)