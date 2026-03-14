---
name: monitor-observablility
description: 为生产应用实现全面的监控、日志、指标、追踪和告警，确保系统可靠性和快速事件响应。当用户需要设置监控、日志、指标、告警、分布式追踪、健康检查、可观测性系统时使用此 skill。
---

# 监控与可观测性

系统健康监控，确保可靠性。

## 三大支柱

| 支柱 | 说明 | 示例 |
|------|------|------|
| **指标** | 时间序列数据 | CPU、内存、请求/秒 |
| **日志** | 带上下文的事件记录 | 错误日志、访问日志 |
| **追踪** | 请求在系统中的流转 | 分布式调用链 |

## 请求监控中间件

```typescript
import * as Sentry from '@sentry/node';
import { metrics } from './metrics';

app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    metrics.histogram('request_duration', duration, {
      method: req.method,
      route: req.route?.path,
      status: res.statusCode,
    });
    if (res.statusCode >= 400) {
      Sentry.captureMessage(`HTTP ${res.statusCode}: ${req.method} ${req.path}`);
    }
  });
  next();
});
```

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

logger.info('用户登录', { userId: '123', ip: '192.168.1.1' });
```

## 指标收集

```typescript
import { collectDefaultMetrics, Registry, Counter, Histogram } from 'prom-client';

const register = new Registry();
collectDefaultMetrics({ register });

const requestCounter = new Counter({
  name: 'http_requests_total',
  help: 'HTTP 请求总数',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

requestCounter.inc({ method: 'GET', route: '/api/users', status: '200' });
```

## 健康检查

```typescript
app.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    checks: {
      database: await checkDatabase(),
      redis: await checkRedis(),
    },
  };
  const allHealthy = Object.values(health.checks).every(c => c.status === 'ok');
  res.status(allHealthy ? 200 : 503).json(health);
});
```

## 告警规则

```yaml
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

      - alert: ServiceDown
        expr: up{job="my-service"} == 0
        for: 1m
        labels:
          severity: critical
```

## 常用工具

| 类别 | 工具 | 用途 |
|------|------|------|
| 指标 | Prometheus | 指标收集和存储 |
| 仪表板 | Grafana | 可视化 |
| 日志 | ELK Stack | 日志聚合和分析 |
| 追踪 | Jaeger | 分布式追踪 |
| 错误追踪 | Sentry | 错误监控 |