# Security Implementation Ec2 & Docker

This README provides an overview of the security implementations on your AWS EC2 Linux instance running a Dockerized application. The security measures include the use of Fail2Ban for Nginx and SSH, AWS Web Application Firewall (WAF), ModSecurity with the OWASP Core Rule Set, and CloudWatch for monitoring and logging.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Security Implementations](#security-implementations)
   - [Fail2Ban](#fail2ban)
   - [AWS WAF](#aws-waf)
   - [ModSecurity with OWASP Core Rule Set](#modsecurity-with-owasp-core-rule-set)
   - [CloudWatch for Monitoring and Logging](#cloudwatch-for-monitoring-and-logging)
3. [Before Implementation Results](#before-implementation-results)
4. [After Implementation Results](#after-implementation-results)

## Prerequisites

Before implementing the security measures, ensure that the following prerequisites are met:

- An AWS EC2 instance running a Linux operating system.
- Docker installed on the EC2 instance.
- Dockerized application deployed on the EC2 instance.
- Access to AWS WAF for configuration.
- Docker images for Fail2Ban, Nginx, ModSecurity, and Vue.js Alpine.

## Security Implementations

### Fail2Ban

Fail2Ban has been implemented to enhance security by monitoring Nginx and SSH logs for suspicious activities and dynamically updating firewall rules to block malicious IP addresses.

- **Configuration**: The Fail2Ban Installation and configuration is done using the below instructions.
#### Update Package Lists
Update the package lists to ensure you have the latest information on available packages.
```bash
sudo yum update -y
```
#### Install Fail2Ban
```bash
sudo yum install fail2ban
```
#### Configure Fail2Ban
- Copy the Fail2Ban configuration file to create a local configuration file.
```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```
#### Edit the Configuration:
```bash
sudo nano /etc/fail2ban/jail.local
```
#### Update SSH Section:
- Locate the [sshd] section and make sure the following settings are configured:
```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
```
#### Start Fail2Ban
- Start the Fail2Ban service.
```bash
sudo systemctl start fail2ban
```
#### Enable Fail2Ban on Boot
- Enable Fail2Ban to start on boot.
```bash
sudo systemctl enable fail2ban
```
#### Test Fail2Ban
Try intentionally failing SSH logins to test if Fail2Ban is working. After reaching the configured maxretry threshold, Fail2Ban should add a ban entry for the IP address.

#### Customize Ban Time and Other Settings
If needed, you can further customize Fail2Ban settings in the /etc/fail2ban/jail.local file, including ban time, email notifications, and more.
```ini
[DEFAULT]
# Ban duration (in seconds)
bantime = 3600

# Email settings
destemail = your-email@example.com
sender = fail2ban@example.com
```
- **Nginx Logs Monitoring**: Fail2Ban is set up to monitor Nginx and SSH logs, reacting to repetitive failed login attempts and other specified patterns.
#### Create a Filter Configuration for Nginx
 - Create a new filter configuration file:
```bash
sudo nano /etc/fail2ban/filter.d/nginx.conf
```
#### Add the following content to the file:
```ini
[Definition]
failregex = ^<HOST>.*"(GET|POST).*HTTP.*" 40[134]
            ^<HOST> -.*"(GET|POST).*HTTP.*" 40[134]
            ^<HOST> .*".*php.* HTTP/.*" 40[134]
            ^<HOST>.*"GET.*wp-login.php.*" 40[134]
ignoreregex
```
#### Update Fail2Ban Configuration
- Open the local Fail2Ban configuration file:
```bash
sudo nano /etc/fail2ban/jail.local
```
#### Add a new section for Nginx:
```ini
[nginx]
enabled = true
port = http,https
filter = nginx
logpath = /var/log/nginx/*.log
maxretry = 3
```
#### Nginx Logs Mapping using Persistent Volume:
As in my case i am running my application in Dockers containers so I have added the persistent volume to store the Nginx logs permanently and pointed these logs in /var/log/nginx/*.log to achieve the same please change your docker-compose.yml and add the below configs in it.
```yml
frontend:
    image: docker_hub_account/timebot-be:frontend
    depends_on:
      - web
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - nginx_data:/var/log/nginx
volumes:
  nginx_data:

```

#### Restart Fail2Ban
- Restart the Fail2Ban service to apply the changes.
```bash
sudo systemctl restart fail2ban
```
#### Test Fail2Ban with Nginx Logs
- Generate some failed attempts in Nginx logs:
Intentionally make some requests to your web application that trigger the rules defined in the Nginx filter.
#### Check Fail2Ban status:
```bash
sudo fail2ban-client status nginx
sudo fail2ban-client status sshd
```

### AWS WAF

AWS Web Application Firewall (WAF) has been configured to protect your web application from common web exploits.

- **AWS Console**: The AWS WAF configuration can be managed through the AWS Management Console.
For Implementing the AWS WAF we first need to implement the AWS elastic load balancer for our server

 ### Implementing ELB

 Go to AWS console->EC2->Load Balancer->Create Load Balancer and now select the Application load balancer

- **Rules and Conditions**: Custom rules and conditions have been set up to filter and block malicious traffic based on specified conditions.

### ModSecurity with OWASP Core Rule Set

ModSecurity, along with the OWASP Core Rule Set (CRS), has been implemented as a web application firewall to protect against various web application attacks.  
Here are two options to implement this according to your requirements.  

- Option 1: For alpine images build the fully customized nginx with modsecurity with Dockerfile according to the requirements.
- Option 2: We can also use the docker image build by the OWASP for Nginx with modsecurity

Note: The option 1 is for fully customising the nginx and modsecurity as the modsecurity is simply offered with the Nginx Plus 
  
We will visit the both solutions:    

#### Option 1: Building the Nginx with Modsec and OWASP
To follow this option copy the below files from this repo to the root of your projet 
- modsec folder
- Dockerfile
- default.conf
- nginx.conf

and run
```bash
docker build -t nginx-modsec:latest .
```
Now First run a test container with newly created image
```bash
docker run --name modsec-nginx-test -p 80:80 nginx-modsec:latest
```
Now test this solution

#### Option 2: Use the OWASP created Docker image

- **Docker Image**: The ModSecurity Docker image with the OWASP CRS is pulled from the Docker Hub (`owasp/modsecurity-crs`) and integrated into my Vue.js Alpine container.
For achieving this add follow the below Dockerfile and modify this according to your needs

```yml
# Use an official Node runtime as the parent image
FROM node:14

# Set the working directory in the container
WORKDIR /app

# Copy package.json and package-lock.json before other files
# Utilize Docker cache to save re-installing dependencies if unchanged
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the current directory contents into the container at /app
COPY . .

# Set the host for the development server to 0.0.0.0 so it can accept connections from any IP address
ENV HOST=0.0.0.0

# Build the app
RUN npm run build

# Use a production-ready server like Nginx to serve the app
FROM owasp/modsecurity-crs:nginx-alpine
COPY --from=0 /app/dist /usr/share/nginx/html


COPY default.conf /etc/nginx/conf.d/timebot.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

```
You can test this image as well by running below
```bash
docker run --name modsec-nginx-test -p 80:80 nginx-modsec:latest
```
- **Configuration**: The ModSecurity configuration files are present in the `/etc/modsecurity/` directory. Adjustments can be made in the `modsecurity.conf` file.

### CloudWatch for Monitoring and Logging

CloudWatch is configured to monitor and log Nginx container activities. The Nginx container logs are stored in a persistent volume accessible by CloudWatch for centralized logging.

- **Configuration**: The CloudWatch logging configuration can be managed through the AWS Management Console.

- **Persistent Volume**: The persistent volume for Nginx logs is configured to allow CloudWatch to access and collect logs for monitoring purposes.

## Before Implementation Results

Before implementing the security measures, assess the server's security posture and record relevant metrics. This may include logs of failed login attempts, Nginx access logs, and any other relevant information.

Add any specific metrics, logs, or details relevant to your application and infrastructure.

## After Implementation Results

After implementing the security measures, reassess the server's security posture and record the improvements. Include metrics such as reduced failed login attempts, blocked malicious IP addresses, and any other relevant information.

Compare the results with the before-implementation metrics to gauge the effectiveness of the implemented security measures.

## Conclusion

This README provides an overview of the security implementations on your AWS EC2 instance. Regularly monitor and update security configurations to adapt to evolving threats and ensure the ongoing protection of your application and infrastructure.
