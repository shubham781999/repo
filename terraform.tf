provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAUS4SSG6ZFJHD7XKG"
  secret_key = "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"
}

variable "enable_public_ip" {
  description = "Enable public IP address"
  type        = bool
  default     = true
}

resource "aws_instance" "wordpress" {
  ami                         = "ami-007020fd9c84e18c7"
  instance_type               = "t2.micro"
  subnet_id                   = "subnet-096d553cfdfeb65b6"
  key_name                    = "keypair"
  associate_public_ip_address = var.enable_public_ip

  vpc_security_group_ids      = [aws_security_group.wordpress_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install nginx -y
    apt-get install php-fpm php-mysql -y
    apt-get install mysql-server -y

    # Start MySQL service
    systemctl start mysql

    # MySQL setup with root privileges
    mysql -u root <<EOFMYSQL
    ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Testpassword@123';
    CREATE DATABASE wp;
    CREATE USER 'wp_user'@'localhost' IDENTIFIED BY 'Testpassword@123';
    GRANT ALL PRIVILEGES ON wp.* TO 'wp_user'@'localhost';
    FLUSH PRIVILEGES;
    EOFMYSQL

    # Download and configure WordPress
    cd /tmp
    wget https://wordpress.org/latest.tar.gz
    tar -xvf latest.tar.gz
    mv wordpress /var/www/html/

    # Set permissions
    chmod -R 755 /var/www/html/wordpress
    chown -R www-data:www-data /var/www/html/wordpress

    # Configure Nginx
    cat <<EOT > /etc/nginx/sites-available/wordpress
    server {
        listen 80;
        server_name _;
        root /var/www/html/wordpress;

        index index.php index.html index.htm;

        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }

        location ~ \.php\$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        }

        location ~ /\.ht {
            deny all;
        }
    }
    EOT

    ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
    systemctl reload nginx
    systemctl restart php8.1-fpm
  EOF

  tags = {
    Name = "Terraform EC2"
  }
}

resource "aws_security_group" "wordpress_sg" {
  name_prefix = "wordpress-nginx-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress-nginx-sg"
  }
}
