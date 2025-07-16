// gRPC/WebSocket messaging service

import { Server, ServerCredentials } from '@grpc/grpc-js';
import { loadPackageDefinition } from '@grpc/proto-loader';
import * as WebSocket from 'ws';

// Load proto file
// Replace with actual proto file path
const packageDefinition = loadPackageDefinition('proto/message.proto');
const grpcPackage = grpc.loadPackageDefinition(packageDefinition).your_proto_package;

// Create gRPC server
const grpcServer = new Server();

// Add service implementations
// grpcServer.addService(grpcPackage.MessageService.service, {
//   yourServiceMethod: (call, callback) => {
//     // Implementation
//   },
// });

// Start gRPC server
const startGrpcServer = (port: number) => {
  grpcServer.bindAsync(`0.0.0.0:${port}`, ServerCredentials.createInsecure(), () => {
    grpcServer.start();
    console.log(`gRPC server started on port ${port}`);
  });
};

// Create WebSocket server
const startWebSocketServer = (port: number) => {
  const wss = new WebSocket.Server({ port }, () => {
    console.log(`WebSocket server started on port ${port}`);
  });

  // Handle WebSocket connections
  wss.on('connection', (ws) => {
    console.log('WebSocket client connected');
    ws.on('message', (message) => {
      console.log('Received message:', message);
    });

    ws.send('Welcome to WebSocket server');
  });
};

export { startGrpcServer, startWebSocketServer };
