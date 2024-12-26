#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Prompt for configuration details
read -p "Enter domain name (e.g., example.com): " domain_name
read -p "Enter application port (default: 3000): " app_port
app_port=${app_port:-3000}
read -p "Do you want to configure static files? (y/n): " static_files
if [ "$static_files" = "y" ]; then
    read -p "Enter path to static files: " static_path
fi

# Create config directory if it doesn't exist
mkdir -p /etc/nginx/sites-available/

# Generate the configuration file
config_file="/etc/nginx/sites-available/$domain_name"
cat > "$config_file" << EOF
server {
    listen 80;
    server_name ${domain_name};

    # Logs
    access_log /var/log/nginx/\${domain_name}.access.log;
    error_log /var/log/nginx/\${domain_name}.error.log;

    location / {
        proxy_pass http://localhost:${app_port};
        proxy_http_version 1.1;
        
        # Headers for proxying
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
EOF

# Add static files configuration if requested
if [ "$static_files" = "y" ]; then
    cat >> "$config_file" << EOF

    location /static/ {
        alias ${static_path};
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
EOF
fi

# Close the server block
echo "}" >> "$config_file"

# Create symbolic link
ln -sf "$config_file" /etc/nginx/sites-enabled/

# Test nginx configuration
echo "Testing Nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "Configuration test successful!"
    
    # Reload nginx
    systemctl reload nginx
    
    echo "Virtual host created and nginx reloaded successfully!"
    echo "Configuration file: $config_file"
else
    echo "Configuration test failed. Please check the syntax."
    exit 1
fi
