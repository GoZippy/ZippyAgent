/**
 * @fileoverview Event Bus Service
 * @description A centralized event bus for module communication
 */

import { EventEmitter } from 'eventemitter3';

export type EventMessage = {
  type: string;
  payload: any;
};

class EventBus extends EventEmitter {
  constructor() {
    super();
  }

  // Publish an event to all subscribers
  publish(event: string, message: EventMessage) {
    this.emit(event, message);
  }

  // Subscribe to an event
  subscribe(event: string, listener: (message: EventMessage) => void) {
    this.on(event, listener);
  }

  // Unsubscribe from an event
  unsubscribe(event: string, listener: (message: EventMessage) => void) {
    this.off(event, listener);
  }
}

export const eventBus = new EventBus();

export const publishEvent = (event: string, message: EventMessage) =>
  eventBus.publish(event, message);

export const subscribeToEvent = (
  event: string,
  listener: (message: EventMessage) => void
) => eventBus.subscribe(event, listener);

export const unsubscribeFromEvent = (
  event: string,
  listener: (message: EventMessage) => void
) => eventBus.unsubscribe(event, listener);
