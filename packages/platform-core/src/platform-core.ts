/**
 * @fileoverview Platform Core Orchestrator
 * @description Main service orchestrator for all platform core services
 */

import { EventEmitter } from 'eventemitter3';
import { ServiceConfig } from './types';
import { logger, PlatformLogger } from './logging/logger';
import { monitoringService } from './monitoring';
import { eventBus } from './event-bus';
import { agentSupervisor } from './supervision';

export class PlatformCore extends EventEmitter {
  private config: ServiceConfig;
  private logger: PlatformLogger;
  private isInitialized = false;
  private services: Map<string, any> = new Map();

  constructor(config: ServiceConfig) {
    super();
    this.config = config;
    this.logger = logger.child({ service: 'platform-core', version: config.version });
  }

  async initialize(): Promise<void> {
    if (this.isInitialized) {
      throw new Error('Platform core already initialized');
    }

    this.logger.info('Initializing Platform Core', { config: this.config });

    try {
      // Initialize monitoring service
      this.services.set('monitoring', monitoringService);
      this.logger.info('Monitoring service initialized');

      // Initialize event bus
      this.services.set('eventBus', eventBus);
      this.logger.info('Event bus initialized');

      // Initialize agent supervisor
      this.services.set('supervisor', agentSupervisor);
      this.logger.info('Agent supervisor initialized');

      // Set up event listeners
      this.setupEventListeners();

      this.isInitialized = true;
      this.emit('initialized');
      this.logger.info('Platform Core initialized successfully');

    } catch (error) {
      this.logger.error('Failed to initialize Platform Core', error);
      throw error;
    }
  }

  private setupEventListeners(): void {
    // Log all events through the event bus
    eventBus.on('*', (event, data) => {
      this.logger.debug('Event received', { event, data });
    });

    // Handle agent supervision events
    agentSupervisor.on('agent_fail', ({ agentId }) => {
      this.logger.warn('Agent failed heartbeat check', { agentId });
      this.emit('agent_failed', { agentId });
    });

    agentSupervisor.on('heartbeat_received', ({ agentId }) => {
      this.logger.debug('Heartbeat received', { agentId });
    });
  }

  async shutdown(): Promise<void> {
    if (!this.isInitialized) {
      return;
    }

    this.logger.info('Shutting down Platform Core');

    try {
      // Shutdown services in reverse order
      const serviceNames = Array.from(this.services.keys()).reverse();
      for (const serviceName of serviceNames) {
        const service = this.services.get(serviceName);
        if (service && typeof service.shutdown === 'function') {
          await service.shutdown();
          this.logger.info(`${serviceName} service shutdown`);
        }
      }

      this.services.clear();
      this.isInitialized = false;
      this.emit('shutdown');
      this.logger.info('Platform Core shutdown completed');

    } catch (error) {
      this.logger.error('Error during shutdown', error);
      throw error;
    }
  }

  getService<T>(serviceName: string): T | undefined {
    return this.services.get(serviceName);
  }

  isServiceAvailable(serviceName: string): boolean {
    return this.services.has(serviceName);
  }

  async healthCheck(): Promise<{ status: 'healthy' | 'unhealthy'; services: Record<string, any> }> {
    const serviceHealth: Record<string, any> = {};
    let overallStatus: 'healthy' | 'unhealthy' = 'healthy';

    for (const [serviceName, service] of this.services) {
      try {
        if (service && typeof service.healthCheck === 'function') {
          const health = await service.healthCheck();
          serviceHealth[serviceName] = health;
          if (health.status !== 'healthy') {
            overallStatus = 'unhealthy';
          }
        } else {
          serviceHealth[serviceName] = { status: 'healthy', message: 'Service available' };
        }
      } catch (error) {
        serviceHealth[serviceName] = { status: 'unhealthy', error: error.message };
        overallStatus = 'unhealthy';
      }
    }

    return {
      status: overallStatus,
      services: serviceHealth
    };
  }

  getConfiguration(): ServiceConfig {
    return { ...this.config };
  }

  updateConfiguration(updates: Partial<ServiceConfig>): void {
    this.config = { ...this.config, ...updates };
    this.logger.info('Configuration updated', { updates });
    this.emit('config_updated', { config: this.config });
  }

  getLogger(): PlatformLogger {
    return this.logger;
  }

  getMetrics(): Promise<string> {
    return monitoringService.getMetrics();
  }

  async registerAgent(agentId: string): Promise<void> {
    agentSupervisor.registerAgent(agentId);
    this.logger.info('Agent registered', { agentId });
    this.emit('agent_registered', { agentId });
  }

  async unregisterAgent(agentId: string): Promise<void> {
    agentSupervisor.removeAgent(agentId);
    this.logger.info('Agent unregistered', { agentId });
    this.emit('agent_unregistered', { agentId });
  }
}

// Export a default instance factory
export const createPlatformCore = (config: ServiceConfig): PlatformCore => {
  return new PlatformCore(config);
};

// Export convenience function for creating a default configuration
export const createDefaultConfig = (): ServiceConfig => ({
  name: 'platform-core',
  version: '1.0.0',
  environment: process.env.NODE_ENV || 'development',
  port: 8080,
  host: '0.0.0.0',
  enableMetrics: true,
  enableLogging: true,
  logLevel: 'info'
});
