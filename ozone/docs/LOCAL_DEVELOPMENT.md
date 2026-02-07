# Quick Start Without AWS (Frontend Development Only)

If you want to work on the demo frontend without deploying to AWS, follow these steps:

## 1. Setup Frontend

```bash
cd src/frontend

# Create a mock config for local testing
cat > config.json << 'EOF'
{
  "apiEndpoint": "http://localhost:5000",
  "version": "1.0.0",
  "environment": "local-dev"
}
EOF
```

## 2. Create Mock API (Optional)

Create a simple Flask server to test frontend without AWS:

```bash
# Install Flask
pip3 install flask flask-cors

# Create mock API
cat > mock-api.py << 'EOF'
from flask import Flask, request, jsonify
from flask_cors import CORS
import time

app = Flask(__name__)
CORS(app)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "version": "1.0-mock"})

@app.route('/chat', methods=['POST'])
def chat_protected():
    data = request.json
    prompt = data.get('prompt', '')
    
    # Simulate WAF blocking
    if any(pattern in prompt.lower() for pattern in ['ignore', 'bypass', 'dan']):
        return jsonify({
            "error": "Request blocked by AI WAF",
            "code": "SECURITY_VIOLATION",
            "risk_score": 85,
            "reason": ["Malicious pattern detected"],
            "detected_patterns": ["Forbidden phrase found"]
        }), 403
    
    # Simulate normal response
    return jsonify({
        "response": f"Mock response to: {prompt}",
        "risk_score": 15,
        "processing_time_ms": 234,
        "metadata": {
            "guardrails_passed": True,
            "output_verified": True
        }
    })

@app.route('/chat-direct', methods=['POST'])
def chat_unprotected():
    data = request.json
    prompt = data.get('prompt', '')
    
    # No filtering - always responds
    return jsonify({
        "response": f"Unprotected mock response to: {prompt}",
        "warning": "Generated WITHOUT security checks",
        "metadata": {
            "guardrails_passed": False,
            "output_verified": False
        }
    })

if __name__ == '__main__':
    app.run(port=5000, debug=True)
EOF

# Run mock API in background
python3 mock-api.py &
```

## 3. Run Frontend

```bash
# In another terminal
cd src/frontend
python3 -m http.server 8080

# Open browser
open http://localhost:8080
```

## 4. Test the Demo

1. Toggle WAF ON/OFF
2. Try attack scenarios
3. See mock blocking behavior
4. Develop frontend features without AWS

## When Ready for AWS

Once you want to deploy to real AWS infrastructure:

```bash
# Configure AWS credentials
aws configure

# Run full setup
make setup

# Edit terraform.tfvars with your settings
nano infra/terraform.tfvars

# Deploy
make deploy ENV=dev
make demo
```

## Development Workflow

```bash
# Frontend changes
cd src/frontend
# Edit HTML/CSS/JS
# Refresh browser

# API changes  
# Edit mock-api.py
# Restart: pkill -f mock-api && python3 mock-api.py &
```

This allows you to develop and test the frontend completely offline!
