#!/bin/bash

# --- 1. System Update and Installation (Ubuntu specific) ---

# Update package list
apt update -y 

# Install required packages (Docker, Nginx, OpenSSL utilities)
apt install -y docker.io nginx openssl 

# --- 2. Docker Service Configuration ---

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add the current user (ubuntu, or adjust if using a custom AMI) to the docker group
# Note: For Ubuntu AMIs, the default user is usually 'ubuntu'.
usermod -aG docker ubuntu 

# Log out and log back in (not possible in User Data), so we proceed as root for the rest of the script.

# --- 3. Run Docker Container ("Namaste from Container") ---
mkdir -p /home/ubuntu/docker-content
echo "Namaste from Container" > /home/ubuntu/docker-content/index.html

docker run -d \
  --name namaste-app \
  -p 8080:80 \
  -v /home/ubuntu/docker-content:/usr/share/nginx/html:ro \
  --restart always \
  nginx:alpine

# --- 4. Generate Self-Signed SSL Certificates ---
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/self-signed.key \
  -out /etc/nginx/ssl/self-signed.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=ec2-instance.yourdomain.com"

# --- 5. Configure Nginx (No change needed here, Nginx config is portable) ---
cat <<EOF > /etc/nginx/conf.d/app.conf
# Redirect HTTP -> HTTPS
server {
    listen 80;
    server_name ec2-instance.yourdomain.com ec2-docker.yourdomain.com;
    return 301 https://\$host\$request_uri;
}

# Serve Static Content (Hello from Instance)
server {
    listen 443 ssl;
    server_name ec2-instance.yourdomain.com;

    ssl_certificate /etc/nginx/ssl/self-signed.crt;
    ssl_certificate_key /etc/nginx/ssl/self-signed.key;

    location / {
        default_type text/plain;
        return 200 "Hello from Instance";
    }
}

# Proxy to Docker (Namaste from Container)
server {
    listen 443 ssl;
    server_name ec2-docker.yourdomain.com;

    ssl_certificate /etc/nginx/ssl/self-signed.crt;
    ssl_certificate_key /etc/nginx/ssl/self-signed.key;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# --- 6. Start Nginx ---

# Ubuntu Nginx usually includes a default site config in sites-enabled, not conf.d/default.conf. 
# We disable the default site to ensure our app.conf is the only configuration.
rm -f /etc/nginx/sites-enabled/default

systemctl start nginx
systemctl enable nginx