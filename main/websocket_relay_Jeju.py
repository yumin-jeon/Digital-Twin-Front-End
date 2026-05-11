#!/usr/bin/env python3
"""
WebSocket Relay for MATLAB-Cesium Satellite Control (v6)

This script serves as a bridge between MATLAB and Cesium:
- Reads telemetry data from MATLAB's JSON output file
- Sends data to connected Cesium clients via WebSockets
- Receives commands from Cesium and writes them to a file for MATLAB
- Supports control mode switching

v6 Changes:
- Added ctrl_mode support for control mode switching
- Preserves ctrl_mode in command file between commands
"""

import asyncio
import json
import os
import logging
import time
import websockets
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# ============= CONFIG =============
class Config:
    # --- Path base ---
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))           # .../main
    REPO_ROOT  = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir)) # repo root
    DATA_DIR   = os.path.join(REPO_ROOT, "data")                      # repo/data

    # File paths (absolute)
    TELEMETRY_FILE = os.path.join(DATA_DIR, "telemetry_out.json")
    TARGET_FILE    = os.path.join(DATA_DIR, "target_out.json")
    COMMAND_FILE   = os.path.join(DATA_DIR, "command_in.json")

    # WebSocket server settings
    HOST = "localhost"
    PORT = 8765

    # Timeouts and intervals (seconds)
    TELEMETRY_STALE_THRESHOLD = 5
    WARNING_INTERVAL = 10
    STATUS_INTERVAL = 60
    RECONNECT_DELAY = 3
    FILE_READ_DELAY = 0.05



# ============= LOGGING SETUP =============
def setup_logging():
    """Configure logging with appropriate format and level"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    return logging.getLogger("WebSocketRelay")

# ============= FILE HANDLING =============
class OutputFileHandler(FileSystemEventHandler):
    """Handler for MATLAB output file change events"""
    
    def __init__(self, telemetry_manager, event_loop):
        self.telemetry_manager = telemetry_manager
        self.event_loop = event_loop
        self.logger = logging.getLogger("WebSocketRelay.FileHandler")
    
    def on_modified(self, event):
        """Handle file modification events"""
        self._handle_output_event(event)

    def on_created(self, event):
        """Handle atomic-replace style file creation events"""
        self._handle_output_event(event)

    def _handle_output_event(self, event):
        if event.is_directory:
            return

        event_path = os.path.normcase(os.path.abspath(event.src_path))
        telemetry_path = os.path.normcase(os.path.abspath(Config.TELEMETRY_FILE))
        target_path = os.path.normcase(os.path.abspath(Config.TARGET_FILE))

        if event_path == telemetry_path:
            self.event_loop.call_soon_threadsafe(
                lambda: asyncio.create_task(self.telemetry_manager.read_telemetry())
            )
        elif event_path == target_path:
            self.event_loop.call_soon_threadsafe(
                lambda: asyncio.create_task(self.telemetry_manager.read_targets())
            )

class TelemetryManager:
    """Manages telemetry data reading and processing"""
    
    def __init__(self, broadcaster):
        self.broadcaster = broadcaster
        self.last_telemetry = {"initialized": False}
        self.last_target_packet = {"initialized": False}
        self.last_telemetry_time = 0
        self.last_target_count = None
        self.logger = logging.getLogger("WebSocketRelay.TelemetryManager")
    
    async def read_telemetry(self):
        """Read and process telemetry from the file"""
        try:
            await asyncio.sleep(Config.FILE_READ_DELAY)
            
            with open(Config.TELEMETRY_FILE, 'r') as f:
                file_content = f.read().strip()

                if not file_content:
                    self.logger.warning("Telemetry file is empty")
                    return
                    
                telemetry = json.loads(file_content)

                if self._is_telemetry_changed(self.last_telemetry, telemetry):
                    self.logger.info(f"New telemetry: {self._get_telemetry_summary(telemetry)}")

                self.last_telemetry = telemetry
                self.last_telemetry_time = time.time()

                await self.broadcaster.broadcast_packet(telemetry)
                
        except json.JSONDecodeError as e:
            self.logger.error(f"JSON decode error in telemetry file: {e}")
        except FileNotFoundError:
            self.logger.error(f"Telemetry file not found: {Config.TELEMETRY_FILE}")
        except PermissionError:
            self.logger.error(f"Permission denied when accessing telemetry file")
        except Exception as e:
            self.logger.error(f"Error reading telemetry file: {str(e)}", exc_info=True)

    async def read_targets(self):
        """Read and broadcast target-only updates from target_out.json"""
        try:
            await asyncio.sleep(Config.FILE_READ_DELAY)

            with open(Config.TARGET_FILE, 'r') as f:
                file_content = f.read().strip()

                if not file_content:
                    self.logger.warning("Target file is empty")
                    return

                target_packet = json.loads(file_content)

                target_count = self._count_targets(target_packet)
                if target_count != self.last_target_count:
                    sample_window = target_packet.get("sample_window", [])
                    self.logger.info(
                        f"[TargetLayer] target_out contains {target_count} targets, "
                        f"sample_window={sample_window}"
                    )
                    self.last_target_count = target_count

                self.last_target_packet = target_packet
                await self.broadcaster.broadcast_packet(target_packet)

        except json.JSONDecodeError as e:
            self.logger.error(f"JSON decode error in target file: {e}")
        except FileNotFoundError:
            self.logger.error(f"Target file not found: {Config.TARGET_FILE}")
        except PermissionError:
            self.logger.error("Permission denied when accessing target file")
        except Exception as e:
            self.logger.error(f"Error reading target file: {str(e)}", exc_info=True)
    
    def _is_telemetry_changed(self, old, new):
        if not old or not new:
            return True
        for key in ['position_ecef', 'quaternion', 'time', 'ctrl_mode']:
            if key in new and (key not in old or old[key] != new[key]):
                return True
        return False
    
    def _get_telemetry_summary(self, telemetry):
        summary = {}
        if 'time' in telemetry:
            summary['time'] = telemetry['time']
        if 'ctrl_mode' in telemetry:
            summary['mode'] = telemetry['ctrl_mode']
        if 'position_ecef' in telemetry:
            pos = telemetry['position_ecef']
            summary['pos'] = f"({pos[0]:.0f}, {pos[1]:.0f}, {pos[2]:.0f})"
        return summary

    def _count_targets(self, packet):
        if isinstance(packet.get('target_count'), int):
            return packet['target_count']

        targets = packet.get('targets', [])
        if isinstance(targets, list):
            return len(targets)
        if isinstance(targets, dict):
            return 1
        return 0

# ============= WEBSOCKET HANDLING =============
class WebSocketServer:
    """Manages WebSocket connections and communication with clients"""
    
    def __init__(self):
        self.connected_clients = set()
        self.client_command_count = {}
        self.logger = logging.getLogger("WebSocketRelay.WebSocketServer")
        self.current_ctrl_mode = 7  # Track current control mode
    
    async def handle_websocket(self, websocket):
        """Handle a WebSocket connection from a client"""
        self.connected_clients.add(websocket)
        client_id = id(websocket)
        
        remote_address = websocket.remote_address
        if isinstance(remote_address, tuple) and len(remote_address) >= 2:
            client_ip, client_port = remote_address[0], remote_address[1]
            client_info = f"{client_ip}:{client_port}"
        else:
            client_info = str(remote_address)
        
        self.client_command_count[client_id] = 0
        
        self.logger.info(f"Client connected: {client_info} (ID: {client_id})")
        self.logger.info(f"Total connected clients: {len(self.connected_clients)}")
        
        try:
            async for message in websocket:
                try:
                    data = json.loads(message)
                    
                    self.client_command_count[client_id] += 1
                    count = self.client_command_count[client_id]
                    
                    cmd_str = data.get("command", "")
                    ctrl_mode = data.get("ctrl_mode", -1)
                    
                    # Update current control mode if specified
                    if ctrl_mode >= 0 and ctrl_mode <= 7:
                        self.current_ctrl_mode = ctrl_mode
                        self.logger.info(f"Control mode change requested: {ctrl_mode}")
                    
                    self.logger.info(f"Command #{count} from {client_id}: cmd='{cmd_str}', mode={self.current_ctrl_mode}")
                    
                    # Build command file content
                    output_data = {
                        "command": cmd_str,
                        "ctrl_mode": self.current_ctrl_mode,
                        "timestamp": time.time(),
                        "client_id": str(client_id)
                    }
                    
                    # Optional target-selection fields.
                    for optional_key in ["target_quaternion", "target_id", "target_source", "target_position_ecef"]:
                        if optional_key in data:
                            output_data[optional_key] = data[optional_key]
                    
                    with open(Config.COMMAND_FILE, 'w') as f:
                        json.dump(output_data, f, indent=2)
                    
                    self.logger.debug(f"Wrote command to file: {output_data}")
                        
                except json.JSONDecodeError:
                    self.logger.warning(f"Received invalid JSON from client {client_id}")
                except Exception as e:
                    self.logger.error(f"Error processing message: {str(e)}")
                    
        except websockets.exceptions.ConnectionClosed:
            self.logger.info(f"Client {client_id} connection closed")
        finally:
            await self._remove_client(websocket, client_id)
    
    async def _remove_client(self, websocket, client_id):
        """Remove a client from the connected clients set"""
        if websocket in self.connected_clients:
            self.connected_clients.remove(websocket)
        if client_id in self.client_command_count:
            del self.client_command_count[client_id]
        self.logger.info(f"Client {client_id} removed. Remaining clients: {len(self.connected_clients)}")
    
    async def broadcast_packet(self, packet):
        """Broadcast a JSON packet to all connected clients"""
        if not self.connected_clients:
            return
            
        message = json.dumps(packet)
        success_count = 0
        failed_clients = []
        
        for client in self.connected_clients.copy():
            try:
                await client.send(message)
                success_count += 1
            except Exception as e:
                client_id = id(client)
                self.logger.error(f"Error sending to client {client_id}: {str(e)}")
                failed_clients.append((client, client_id))
        
        for client, client_id in failed_clients:
            await self._remove_client(client, client_id)
        
        if self.connected_clients:
            self.logger.debug(f"Packet broadcast to {success_count}/{len(self.connected_clients)} clients")

    async def broadcast_telemetry(self, telemetry):
        """Backward-compatible alias for telemetry broadcasts"""
        await self.broadcast_packet(telemetry)
    
    async def send_initial_telemetry(self, websocket, telemetry):
        """Send initial telemetry to a newly connected client"""
        if telemetry.get("initialized", False):
            try:
                await websocket.send(json.dumps(telemetry))
                client_id = id(websocket)
                self.logger.info(f"Sent initial telemetry to client {client_id}")
                return True
            except Exception as e:
                client_id = id(websocket)
                self.logger.error(f"Error sending initial telemetry to client {client_id}: {str(e)}")
                return False
        return False

# ============= MONITORING =============
class HealthMonitor:
    """Monitors system health and logs status information"""
    
    def __init__(self, telemetry_manager, websocket_server):
        self.telemetry_manager = telemetry_manager
        self.websocket_server = websocket_server
        self.last_warning = 0
        self.logger = logging.getLogger("WebSocketRelay.HealthMonitor")
    
    async def run(self):
        """Start health check monitoring"""
        self.logger.info("Health check monitoring started")
        
        while True:
            await self._check_telemetry_status()
            await self._log_periodic_status()
            await asyncio.sleep(1)
    
    async def _check_telemetry_status(self):
        """Check if telemetry is being updated regularly"""
        current_time = time.time()
        
        if self.telemetry_manager.last_telemetry_time > 0:
            telemetry_age = current_time - self.telemetry_manager.last_telemetry_time
            
            if telemetry_age > Config.TELEMETRY_STALE_THRESHOLD:
                if current_time - self.last_warning > Config.WARNING_INTERVAL:
                    self.logger.warning(f"No telemetry updates for {telemetry_age:.1f} seconds. Is MATLAB running?")
                    self.last_warning = current_time
            else:
                if current_time - self.last_warning > Config.STATUS_INTERVAL:
                    self.logger.info(f"Telemetry is being updated normally (last update: {telemetry_age:.1f}s ago)")
                    self.last_warning = current_time
        else:
            if current_time - self.last_warning > Config.WARNING_INTERVAL:
                self.logger.warning("No telemetry received since server startup. Waiting for MATLAB...")
                self.last_warning = current_time
    
    async def _log_periodic_status(self):
        """Log periodic status information"""
        current_time = time.time()
        if int(current_time) % Config.STATUS_INTERVAL < 1:
            mode = self.websocket_server.current_ctrl_mode
            self.logger.info(f"Status: {len(self.websocket_server.connected_clients)} clients, mode={mode}")

# ============= FILE INITIALIZATION =============
async def initialize_files():
    """Create initial JSON files if they don't exist"""
    logger = logging.getLogger("WebSocketRelay.Init")
    
    os.makedirs(Config.DATA_DIR, exist_ok=True)

    if not os.path.exists(Config.COMMAND_FILE):
        try:
            with open(Config.COMMAND_FILE, 'w') as f:
                json.dump({"command": "", "ctrl_mode": 7, "initialized": True}, f, indent=2)
            logger.info(f"Created initial {Config.COMMAND_FILE}")
        except Exception as e:
            logger.error(f"Failed to create {Config.COMMAND_FILE}: {str(e)}")
            raise
    
    if not os.path.exists(Config.TELEMETRY_FILE):
        try:
            with open(Config.TELEMETRY_FILE, 'w') as f:
                json.dump({"initialized": False}, f, indent=2)
            logger.info(f"Created initial {Config.TELEMETRY_FILE}")
        except Exception as e:
            logger.error(f"Failed to create {Config.TELEMETRY_FILE}: {str(e)}")
            raise

    if not os.path.exists(Config.TARGET_FILE):
        try:
            with open(Config.TARGET_FILE, 'w') as f:
                json.dump({
                    "type": "target_update",
                    "initialized": False,
                    "target_count": 0,
                    "targets": []
                }, f, indent=2)
            logger.info(f"Created initial {Config.TARGET_FILE}")
        except Exception as e:
            logger.error(f"Failed to create {Config.TARGET_FILE}: {str(e)}")
            raise
    
    logger.info("File initialization complete")

# ============= MAIN APPLICATION =============
class WebSocketRelay:
    """Main application class that coordinates all components"""
    
    def __init__(self):
        self.logger = logging.getLogger("WebSocketRelay.Main")
        self.websocket_server = WebSocketServer()
        self.telemetry_manager = TelemetryManager(self.websocket_server)
        self.health_monitor = HealthMonitor(self.telemetry_manager, self.websocket_server)
        self.observer = None
        self.server = None
        self.event_loop = None
    
    async def start(self):
        """Start the WebSocket relay server"""
        self.event_loop = asyncio.get_running_loop()
        
        self.logger.info("=" * 60)
        self.logger.info("WebSocket Relay v6 - Multi-Mode Satellite Control")
        self.logger.info("=" * 60)
        
        await initialize_files()
        
        if os.path.exists(Config.TELEMETRY_FILE):
            await self.telemetry_manager.read_telemetry()
        if os.path.exists(Config.TARGET_FILE):
            await self.telemetry_manager.read_targets()
        
        data_dir = Config.DATA_DIR
        self.observer = Observer()
        
        try:
            event_handler = OutputFileHandler(self.telemetry_manager, self.event_loop)
            self.observer.schedule(event_handler, path=data_dir, recursive=False)
            self.observer.start()
            self.logger.info(f"Monitoring {Config.TELEMETRY_FILE} for satellite telemetry")
            self.logger.info(f"Monitoring {Config.TARGET_FILE} for target updates")
        except Exception as e:
            self.logger.error(f"Failed to start file observer: {str(e)}", exc_info=True)
            raise
        
        try:
            self.server = await websockets.serve(
                self.websocket_server.handle_websocket, 
                Config.HOST, 
                Config.PORT
            )
            self.logger.info(f"WebSocket server started on ws://{Config.HOST}:{Config.PORT}")
        except OSError as e:
            self.logger.error(f"Failed to start WebSocket server: {str(e)}")
            self.logger.error(f"Port {Config.PORT} may already be in use. Try a different port.")
            self.observer.stop()
            self.observer.join()
            return
        except Exception as e:
            self.logger.error(f"Failed to start WebSocket server: {str(e)}", exc_info=True)
            self.observer.stop()
            self.observer.join()
            return
        
        health_task = asyncio.create_task(self.health_monitor.run())
        
        try:
            self.logger.info("Server running. Press Ctrl+C to stop.")
            self.logger.info("Control modes: 0=NoCtrl, 1=RateDamp, 2=Inertial, 3=Nadir, 4=Interactive, 5=MomBias, 7=TargetPt")
            await asyncio.Future()
        finally:
            self.logger.info("Shutting down...")
            health_task.cancel()
            self.server.close()
            await self.server.wait_closed()
            self.observer.stop()
            self.observer.join()
            self.logger.info("Shutdown complete.")

# ============= ENTRY POINT =============
async def main():
    """Main entry point for the application"""
    relay = WebSocketRelay()
    await relay.start()

if __name__ == "__main__":
    logger = setup_logging()
    
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
        logger.info("Shutting down WebSocket relay")
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        raise
