/**
 * @fileoverview Core Type Definitions
 * @description Shared type definitions for the platform core services
 */

export interface AgentStatus {
  id: string;
  name: string;
  status: 'active' | 'inactive' | 'paused' | 'stopped' | 'error';
  lastHeartbeat: Date;
  pid?: number;
  cpuUsage?: number;
  memoryUsage?: number;
  logPath?: string;
  isHeld: boolean;
  metadata?: Record<string, any>;
}

export interface AgentMetrics {
  agentId: string;
  timestamp: Date;
  cpuUsage: number;
  memoryUsage: number;
  networkIn: number;
  networkOut: number;
  diskUsage: number;
  customMetrics?: Record<string, number>;
}

export interface HeartbeatData {
  agentId: string;
  timestamp: Date;
  status: 'healthy' | 'unhealthy' | 'warning';
  metadata?: Record<string, any>;
}

export interface PlatformEvent {
  id: string;
  type: string;
  source: string;
  timestamp: Date;
  data: Record<string, any>;
  correlationId?: string;
}

export interface ServiceConfig {
  name: string;
  version: string;
  environment: string;
  port?: number;
  host?: string;
  enableMetrics: boolean;
  enableLogging: boolean;
  logLevel: 'debug' | 'info' | 'warn' | 'error';
  [key: string]: any;
}

export interface MessagePayload {
  type: string;
  data: any;
  timestamp: Date;
  source: string;
  correlationId?: string;
}

export interface SupervisionPolicy {
  maxRetries: number;
  retryDelay: number;
  heartbeatTimeout: number;
  failureThreshold: number;
  recoveryStrategy: 'restart' | 'failover' | 'ignore';
}

export interface HealthCheckResult {
  service: string;
  status: 'healthy' | 'unhealthy' | 'degraded';
  timestamp: Date;
  responseTime: number;
  details?: Record<string, any>;
}

export interface LogFilter {
  level?: string;
  service?: string;
  agent?: string;
  startTime?: Date;
  endTime?: Date;
  correlationId?: string;
}

export interface MetricsQuery {
  metric: string;
  startTime: Date;
  endTime: Date;
  labels?: Record<string, string>;
  aggregation?: 'sum' | 'avg' | 'max' | 'min' | 'count';
}
