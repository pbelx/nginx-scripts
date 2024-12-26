#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Prompt for website details
read -p "Enter website directory path: " website_dir
read -p "Enter domain name (e.g., example.com): " domain_name

# Validate directory exists
if [ ! -d "$website_dir" ]; then
    echo "Directory $website_dir does not exist!"
    read -p "Create directory? (y/n): " create_dir
    if [ "$create_dir" = "y" ]; then
        mkdir -p "$website_dir"
        echo "Directory created: $website_dir"
    else
        exit 1
    fi
fi

# Create nginx config
config_file="/etc/nginx/sites-available/$domain_name"
cat > "$config_file" << EOF
server {
    listen 80;
    server_name ${domain_name};

    # Logs
    access_log /var/log/nginx/${domain_name}.access.log;
    error_log /var/log/nginx/${domain_name}.error.log;

    # Root directory
    root ${website_dir};
    index index.html index.htm;

    # Serve static files
    location / {
        try_files \$uri \$uri/ =404;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Handle favicon
    location = /favicon.ico {
        access_log off;
        log_not_found off;
    }

    # Handle 404 errors
    error_page 404 /404.html;
    location = /404.html {
        internal;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

# Create symbolic link
ln -sf "$config_file" /etc/nginx/sites-enabled/

# Create reference file in website directory
cat > "${website_dir}/nginx-info.txt" << EOF
Static Website Configuration Details
---------------------------
Domain: $domain_name
Root Directory: $website_dir
Config File: $config_file
EOF

# Test nginx configuration
echo "Testing Nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "Configuration test successful!"
    
    # Reload nginx
    systemctl reload nginx
    
    echo -e "\nStatic website virtual host created successfully!"
    echo "----------------------------------------"
    echo "Domain: $domain_name"
    echo "Website Directory: $website_dir"
    echo "Config File: $config_file"
    echo "Configuration details saved in: ${website_dir}/nginx-info.txt"
    echo -e "\nMake sure to:"
    echo "1. Place your HTML files in: $website_dir"
    echo "2. Set proper file permissions:"
    echo "   sudo chown -R www-data:www-data $website_dir"
    echo "   sudo chmod -R 755 $website_dir"
else
    echo "Configuration test failed. Please check the syntax."
    exit 1
fi
