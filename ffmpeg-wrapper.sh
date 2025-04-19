#!/usr/bin/env python3
import http.server
import threading
from io import BytesIO
from socketserver import ThreadingMixIn
import base64

PORT_MOTIONEYE = 5081
PORT_FFMPEG = 5091

frame_buffer = BytesIO()
frame_lock = threading.Lock()

# Define username and password for authentication
USERNAME = "motioneye"
PASSWORD = "dontkeepthispassword"

def check_authentication(headers):
    """Check for the correct username and password in the Authorization header."""
    auth_header = headers.get('Authorization')
    if not auth_header:
        return False

    # Extract base64 encoded credentials from the header
    if auth_header.startswith('Basic '):
        encoded_credentials = auth_header[6:]
        decoded_credentials = base64.b64decode(encoded_credentials).decode('utf-8')
        username, password = decoded_credentials.split(':', 1)
        
        # Check if the provided username and password match
        return username == USERNAME and password == PASSWORD
    return False

class MJPEGHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        # Check for Basic Authentication
        if not check_authentication(self.headers):
            self.send_response(401)
            self.send_header('WWW-Authenticate', 'Basic realm="MotionEye"')
            self.end_headers()
            self.wfile.write(b"Unauthorized")
            return

        self.send_response(200)
        self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=--frame')
        self.end_headers()

        print(f"📡 MotionEye connection request from {self.client_address}")
        try:
            while True:
                with frame_lock:
                    frame = frame_buffer.getvalue()
                if frame:
                    self.wfile.write(b"--frame\r\n")
                    self.wfile.write(b"Content-Type: image/jpeg\r\n")
                    self.wfile.write(f"Content-Length: {len(frame)}\r\n\r\n".encode())
                    self.wfile.write(frame)
                    self.wfile.write(b"\r\n")
        except (ConnectionResetError, BrokenPipeError):
            print(f"📴 Connection broken by {self.client_address}")

class UploadHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        print("📥 POST request received")
        print("Headers:", self.headers)

        if self.headers.get('Transfer-Encoding', '') == 'chunked':
            print("🔄 Chunked Transfer-Encoding detected")
            try:
                while True:
                    line = self.rfile.readline()
                    if not line:
                        break
                    chunk_size = int(line.strip(), 16)
                    if chunk_size == 0:
                        break
                    chunk_data = self.rfile.read(chunk_size)
                    self.rfile.read(2)  # Consume \r\n

                    # Save latest frame
                    with frame_lock:
                        frame_buffer.seek(0)
                        frame_buffer.truncate()
                        frame_buffer.write(chunk_data)
            except Exception as e:
                print("⚠ Error with chunked upload:", e)
        else:
            print("⚠ No 'Transfer-Encoding: chunked'")

        self.send_response(200)
        self.end_headers()

class ThreadedHTTPServer(ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

if __name__ == "__main__":
    threading.Thread(
        target=lambda: ThreadedHTTPServer(('', PORT_MOTIONEYE), MJPEGHandler).serve_forever(),
        daemon=True
    ).start()
    print(f"✅ Listening on port {PORT_MOTIONEYE} for MotionEye...")

    print(f"📡 Python server running on port {PORT_FFMPEG} for ffmpeg-client connections...")
    ThreadedHTTPServer(('', PORT_FFMPEG), UploadHandler).serve_forever()
