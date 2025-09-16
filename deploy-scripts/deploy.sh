#!/bin/bash

APP_NAME="myapp"
APP_DIR="/opt/myapp"
SERVICE_NAME="myapp.service"
JAR_FILE=$(ls -t ${APP_DIR}/*.jar | head -1)

echo "Starting deployment of $APP_NAME..."
echo "JAR file: $JAR_FILE"

# Stop existing service if running
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "Stopping existing service..."
    sudo systemctl stop $SERVICE_NAME
fi

# Create or update systemd service file
echo "Creating systemd service file..."
sudo tee /etc/systemd/system/$SERVICE_NAME > /dev/null <<EOF
[Unit]
Description=Spring Boot Application - $APP_NAME
After=network.target
StartLimitIntervalSec=0

[Service]
Type=exec
Restart=always
RestartSec=1
User=ec2-user
ExecStart=/usr/bin/java -server -Xms512m -Xmx512m -jar $JAR_FILE
Environment=SPRING_PROFILES_ACTIVE=prod
WorkingDirectory=$APP_DIR
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$APP_NAME

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable service to start on boot
echo "Enabling service to start on boot..."
sudo systemctl enable $SERVICE_NAME

# Start service
echo "Starting service..."
sudo systemctl start $SERVICE_NAME

# Wait a moment for service to start
sleep 5

# Check service status
echo "Checking service status..."
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "✅ Deployment successful! Service is running."
    sudo systemctl status $SERVICE_NAME --no-pager
else
    echo "❌ Deployment failed! Service is not running."
    sudo journalctl -u $SERVICE_NAME --no-pager -n 20
    exit 1
fi

# Test endpoint (optional)
if command -v curl >/dev/null 2>&1; then
    echo "Testing application endpoint..."
    sleep 20  # Wait for application to fully start
    if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
        echo "✅ Application health check passed!"
    else
        echo "⚠️  Application health check failed, but service is running."
    fi
fi

echo "Deployment completed successfully! 🚀"
