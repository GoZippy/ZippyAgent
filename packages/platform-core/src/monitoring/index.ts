/**
 * @fileoverview Platform Monitoring Service
 * @description Real-time monitoring service with Prometheus metrics integration
 */

import { collectDefaultMetrics, Registry, Gauge, Counter } from 'prom-client';
import { EventEmitter } from 'eventemitter3';

export class MonitoringService extends EventEmitter {
  private registry: Registry;

  constructor() {
    super();
    this.registry = new Registry();
    collectDefaultMetrics({ register: this.registry });
  }

  // Record a custom gauge metric
  recordGauge(name: string, value: number, labels: Record<string, string> = {}) {
    const gauge = new Gauge({
      name,
      help: `Gauge for ${name}`,
      registers: [this.registry],
      labelNames: Object.keys(labels)
    });
    gauge.set(value, labels);
  }

  // Record a custom event count
  recordEvent(name: string, labels: Record<string, string> = {}) {
    const counter = new Counter({
      name,
      help: `Counter for ${name}`,
      registers: [this.registry],
      labelNames: Object.keys(labels)
    });
    counter.inc(labels);
  }

  // Retrieve metrics in Prometheus format
  async getMetrics() {
    return await this.registry.metrics();
  }

  // Real-time event monitoring
  monitorEvent(eventType: string, callback: Function) {
    this.on(eventType, callback);
  }
}

export const monitoringService = new MonitoringService();

// Convenience methods for quick access
export const recordGauge = (name: string, value: number, labels: Record<string, string> = {}) => 
  monitoringService.recordGauge(name, value, labels);

export const recordEvent = (name: string, labels: Record<string, string> = {}) => 
  monitoringService.recordEvent(name, labels);

export const getMetrics = async () => 
  await monitoringService.getMetrics();

export const monitorEvent = (eventType: string, callback: Function) => 
  monitoringService.monitorEvent(eventType, callback);
