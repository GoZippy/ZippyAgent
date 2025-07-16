/**
 * @fileoverview Platform Logging Service
 * @description Comprehensive logging service with structured logging, correlation IDs, and agent context
 */

import winston from 'winston';
import 'winston-daily-rotate-file';
import { v4 as uuidv4 } from 'uuid';
import { EventEmitter } from 'eventemitter3';

export interface LogContext {
  service: string;
  agent?: string;
  correlationId?: string;
  requestId?: string;
  userId?: string;
  sessionId?: string;
  operation?: string;
  environment?: string;
  version?: string;
  [key: string]: any;
}

export interface LogMessage {
  level: string;
  message: string;
  timestamp: string;
  context: LogContext;
  metadata?: Record<string, any>;
  error?: Error;
  stack?: string;
}

export class PlatformLogger extends EventEmitter {
  private logger: winston.Logger;
  private defaultContext: Partial<LogContext>;
  private correlationId: string;

  constructor(defaultContext: Partial<LogContext> = {}) {
    super();
    this.defaultContext = defaultContext;
    this.correlationId = uuidv4();
    
    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json(),
        winston.format.printf(({ timestamp, level, message, ...meta }) => {
          return JSON.stringify({
            timestamp,
            level,
            message,
            ...meta
          });
        })
      ),
      transports: [
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
          )
        }),
        new winston.transports.DailyRotateFile({
          dirname: 'logs',
          filename: 'platform-%DATE%.log',
          datePattern: 'YYYY-MM-DD',
          zippedArchive: true,
          maxSize: '20m',
          maxFiles: '14d'
        }),
        new winston.transports.DailyRotateFile({
          dirname: 'logs',
          filename: 'platform-error-%DATE%.log',
          datePattern: 'YYYY-MM-DD',
          level: 'error',
          zippedArchive: true,
          maxSize: '20m',
          maxFiles: '30d'
        })
      ]
    });
  }

  private buildContext(context: Partial<LogContext> = {}): LogContext {
    return {
      service: 'platform-core',
      correlationId: this.correlationId,
      environment: process.env.NODE_ENV || 'development',
      version: process.env.npm_package_version || '1.0.0',
      ...this.defaultContext,
      ...context
    };
  }

  private logWithContext(level: string, message: string, context: Partial<LogContext> = {}, metadata?: Record<string, any>, error?: Error) {
    const fullContext = this.buildContext(context);
    const logEntry: LogMessage = {
      level,
      message,
      timestamp: new Date().toISOString(),
      context: fullContext,
      metadata,
      error,
      stack: error?.stack
    };

    this.logger.log(level, message, logEntry);
    this.emit('log', logEntry);
  }

  info(message: string, context?: Partial<LogContext>, metadata?: Record<string, any>) {
    this.logWithContext('info', message, context, metadata);
  }

  error(message: string, error?: Error, context?: Partial<LogContext>, metadata?: Record<string, any>) {
    this.logWithContext('error', message, context, metadata, error);
  }

  warn(message: string, context?: Partial<LogContext>, metadata?: Record<string, any>) {
    this.logWithContext('warn', message, context, metadata);
  }

  debug(message: string, context?: Partial<LogContext>, metadata?: Record<string, any>) {
    this.logWithContext('debug', message, context, metadata);
  }

  trace(message: string, context?: Partial<LogContext>, metadata?: Record<string, any>) {
    this.logWithContext('trace', message, context, metadata);
  }

  // Agent-specific logging
  agentLog(agentName: string, message: string, level: string = 'info', metadata?: Record<string, any>) {
    this.logWithContext(level, message, { agent: agentName, service: 'agent' }, metadata);
  }

  // Operation logging with correlation
  startOperation(operation: string, context?: Partial<LogContext>) {
    const operationId = uuidv4();
    this.info(`Starting operation: ${operation}`, { ...context, operation, operationId });
    return operationId;
  }

  endOperation(operationId: string, operation: string, success: boolean, context?: Partial<LogContext>, metadata?: Record<string, any>) {
    const level = success ? 'info' : 'error';
    const message = `${success ? 'Completed' : 'Failed'} operation: ${operation}`;
    this.logWithContext(level, message, { ...context, operation, operationId }, metadata);
  }

  // Performance logging
  performanceLog(operation: string, duration: number, context?: Partial<LogContext>) {
    this.info(`Performance: ${operation} took ${duration}ms`, { ...context, operation }, { duration });
  }

  // Security logging
  securityLog(event: string, severity: 'low' | 'medium' | 'high' | 'critical', context?: Partial<LogContext>, metadata?: Record<string, any>) {
    this.warn(`Security event: ${event}`, { ...context, security: severity }, metadata);
  }

  // Heartbeat logging
  heartbeat(agentName: string, status: 'healthy' | 'unhealthy', metadata?: Record<string, any>) {
    this.info(`Heartbeat: ${agentName} - ${status}`, { agent: agentName, service: 'heartbeat' }, metadata);
  }

  // Create child logger with additional context
  child(additionalContext: Partial<LogContext>): PlatformLogger {
    const childLogger = new PlatformLogger({
      ...this.defaultContext,
      ...additionalContext
    });
    return childLogger;
  }

  // Set correlation ID for request tracing
  setCorrelationId(correlationId: string) {
    this.correlationId = correlationId;
  }

  // Get current correlation ID
  getCorrelationId(): string {
    return this.correlationId;
  }

  // Add structured metadata to all logs
  addMetadata(key: string, value: any) {
    this.defaultContext[key] = value;
  }

  // Remove metadata
  removeMetadata(key: string) {
    delete this.defaultContext[key];
  }
}

// Export a default logger instance
export const logger = new PlatformLogger();

// Export convenience functions
export const logInfo = (message: string, context?: Partial<LogContext>, metadata?: Record<string, any>) => 
  logger.info(message, context, metadata);

export const logError = (message: string, error?: Error, context?: Partial<LogContext>, metadata?: Record<string, any>) => 
  logger.error(message, error, context, metadata);

export const logWarn = (message: string, context?: Partial<LogContext>, metadata?: Record<string, any>) => 
  logger.warn(message, context, metadata);

export const logDebug = (message: string, context?: Partial<LogContext>, metadata?: Record<string, any>) => 
  logger.debug(message, context, metadata);

export const agentLog = (agentName: string, message: string, level?: string, metadata?: Record<string, any>) => 
  logger.agentLog(agentName, message, level, metadata);

export const heartbeat = (agentName: string, status: 'healthy' | 'unhealthy', metadata?: Record<string, any>) => 
  logger.heartbeat(agentName, status, metadata);

export const performanceLog = (operation: string, duration: number, context?: Partial<LogContext>) => 
  logger.performanceLog(operation, duration, context);

export const securityLog = (event: string, severity: 'low' | 'medium' | 'high' | 'critical', context?: Partial<LogContext>, metadata?: Record<string, any>) => 
  logger.securityLog(event, severity, context, metadata);

export const createChildLogger = (additionalContext: Partial<LogContext>) => 
  logger.child(additionalContext);
