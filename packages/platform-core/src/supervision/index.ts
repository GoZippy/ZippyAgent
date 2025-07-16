/**
 * @fileoverview Agent Supervision Service
 * @description Implements agent supervision patterns like heartbeats and retry strategies
 */

import { EventEmitter } from 'eventemitter3';
import { v4 as uuidv4 } from 'uuid';
import { AgentStatus } from '../types';
import { logger } from '../logging/logger';
import { recordEvent } from '../monitoring';

export interface SupervisionOptions {
  heartbeatInterval: number;
  heartbeatTimeout: number;
}

class AgentSupervisor extends EventEmitter {
  private agents: Map<string, NodeJS.Timeout>;
  private options: SupervisionOptions;

  constructor(options: SupervisionOptions) {
    super();
    this.agents = new Map();
    this.options = options;
  }

  // Register an agent for supervision
  registerAgent(agentId: string) {
    this.scheduleHeartbeat(agentId);
    recordEvent('agent_registered', { agentId });
    logger.info(`Agent ${agentId} registered for supervision.`);
  }

  // Schedule heartbeat for an agent
  private scheduleHeartbeat(agentId: string) {
    const timeoutId = setTimeout(() => this.handleHeartbeatTimeout(agentId), this.options.heartbeatTimeout);
    this.agents.set(agentId, timeoutId);
    this.emit('heartbeat_scheduled', { agentId });
  }

  // Handle heartbeat timeout
  private handleHeartbeatTimeout(agentId: string) {
    this.agents.delete(agentId);
    this.emit('agent_fail', { agentId });
    logger.warn(`Agent ${agentId} failed to send heartbeat.`);
  }

  // Receive heartbeat from an agent
  receiveHeartbeat(agentId: string) {
    if (this.agents.has(agentId)) {
      clearTimeout(this.agents.get(agentId)!);
      this.scheduleHeartbeat(agentId);
      this.emit('heartbeat_received', { agentId });
      recordEvent('heartbeat_received', { agentId });
      logger.info(`Heartbeat received from agent ${agentId}.`);
    } else {
      logger.warn(`Heartbeat received from unknown agent ${agentId}.`);
    }
  }

  // Remove an agent from supervision
  removeAgent(agentId: string) {
    if (this.agents.has(agentId)) {
      clearTimeout(this.agents.get(agentId)!);
      this.agents.delete(agentId);
      this.emit('agent_removed', { agentId });
      logger.info(`Agent ${agentId} removed from supervision.`);
    }
  }
}

export const agentSupervisor = new AgentSupervisor({
  heartbeatInterval: 60000, // 60 seconds
  heartbeatTimeout: 120000 // 120 seconds
});

export const registerAgentForSupervision = (agentId: string) => agentSupervisor.registerAgent(agentId);

export const receiveAgentHeartbeat = (agentId: string) => agentSupervisor.receiveHeartbeat(agentId);

export const removeAgentFromSupervision = (agentId: string) => agentSupervisor.removeAgent(agentId);

