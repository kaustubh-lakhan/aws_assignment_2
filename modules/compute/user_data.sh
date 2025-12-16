#!/bin/bash

yum update -y
amazon-linux-extras install docker nginx1 -y
yum install -y openssl


systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# 3. Run Docker Container ("Namaste from Container")
mkdir -p /home/ec2-user/docker-content
echo "Namaste from Container" > /home/ec2-user/docker-content/index.html

docker run -d \
  --name namaste-app \
  -p 8080:80 \
  -v /home/ec2-user/docker-content:/usr/share/nginx/html:ro \
  --restart always \
  nginx:alpine

# 4. Generate Self-Signed SSL Certificates
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/self-signed.key \
  -out /etc/nginx/ssl/self-signed.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=ec2-instance.yourdomain.com"

# 5. Configure Nginx
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

# 6. Start Nginx

mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak 2>/dev/null

systemctl start nginx
systemctl enable nginx