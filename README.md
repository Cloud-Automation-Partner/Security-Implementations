# Security Implementation EC2 & Docker

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

 Go to AWS console->EC2->Load Balancer->Create Load Balancer and now select the Application load balancer and click Create

Enter the name for your ELB  
 <img width="850" alt="Screenshot 2023-12-14 at 12 20 47 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/1f5b3c75-6d19-43cd-ad46-f1a2c3fc9ac6">

Select the VPC in which you wanted to create the ELB and select the availability zones for the ELB
<img width="850" alt="Screenshot 2023-12-14 at 12 21 38 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/024eaa9b-5993-4046-ba62-6bc26e8dc626">  

Now select the security groups for your ELB (We can select one or upto five security groups from the drop down menu)
<img width="850" alt="Screenshot 2023-12-14 at 12 22 54 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/36b72dac-6e0b-442a-a29c-c71f594bd8f6">    

Click on dropdown in the listners tab and select the https:443 this will be the default port for your ELB to accept communication on and for securing your ELB communication use 443 for secure connections and select your target group
<img width="850" alt="Screenshot 2023-12-14 at 12 23 46 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/45f89b1a-d620-41ac-b4c7-5d9adcc88159">

If you do not have any target groups then follow the below  

### Creating Target Group  

**Optional:** For creating the new target group clikck the "Create new Target group"   

Now select "instances" in the target group section  
<img width="850" alt="Screenshot 2023-12-14 at 12 26 29 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/d2412208-5c6e-4923-8e8b-9f7335420d55">  

Enter your target group name and select the port on which you wanted the ELB to communicate with your server (For further enhanced security you can implement SSL certs to your server and make it to communicate on the https:443 it will increase another layer of security)
<img width="850" alt="Screenshot 2023-12-14 at 12 40 44 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/91e1572f-8ada-4c64-b083-bb4475946072">

Select the VPC for your target group (Must be the same as ELB) and leave the protocol version as it is.
<img width="850" alt="Screenshot 2023-12-14 at 12 40 58 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/bb3a75e7-6747-4ddc-9a95-2ae607d96a49">

Leave the health check section as recommended and select "Next"
<img width="850" alt="Screenshot 2023-12-14 at 12 38 26 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/a8ea8357-1268-484a-ad99-f0a8a45b8399">  

Select the EC2 instances here you wanted to add in the ELB (Can  be multiple) in this section and click "Include as pending below"  
<img width="850" alt="Screenshot 2023-12-14 at 12 51 14 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/f2a5d0ae-fd23-469d-a7de-b1314460e728">

Select "add pending target" and select "create target group"    
<img width="850" alt="Screenshot 2023-12-14 at 12 50 32 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/74a4ae9e-67fe-4203-a3d2-2b7c26d6d090">

Now visit back the ELB creation page and reload the target group section your target group will be shown in the dropdwon menu

In secure listners section use the default recommended and select the SSL certificates for your ELB if you have any existing SSL certs you can imort these in AWS or you can simply get the one from the AWS ACM
<img width="850" alt="Screenshot 2023-12-14 at 12 25 09 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/64500b84-f8eb-4303-a2df-f8517ad98b1f">

### Request SSL Certs
**Optional:** To get the SSL certs from ACM Go to Certificate Manager ->Request Certificates ->Request a public certificate  

Enter your domain name  and in the validation method select DNS validation
<img width="850" alt="Screenshot 2023-12-14 at 2 27 21 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/6388fc0f-c526-4c92-b095-be041478f120">

Select key algorithm type and select Request certificates  
<img width="850" alt="Screenshot 2023-12-14 at 2 27 41 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/dfda9ed5-f86d-45e8-a1db-6364c4f2ac9f">

Now copy tha DNS entries from here and add these in your domain DNS and your SSL certs will be issued after a short time
  
**You are done with AWS SSL certs, Continue to ELB**

After selecting the SSL certs in your ELB on the bottom review your selctions and click "Create Load Balancer"  button.   
Now point your domain to the ELB by getting the ELB dns and addding that in your domain DNS to route your all traffic to the ELB.  

### Setup AWS Web Application Firewall  

Go to "WAF & Shield" in AWS click Web ACLs ->Select region ->Create web ACL 
After selecting your region enter the name for your WAF
<img width="850" alt="Screenshot 2023-12-14 at 3 56 12 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/e7692337-d7a6-4416-a7b7-cb4666263e08">  

Click add resources  
<img width="850" alt="Screenshot 2023-12-14 at 3 57 57 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/51f39130-2536-42ee-9b41-5aa11fdd2ac7">  

Select application load balancer and select your required ELB and select Add and then click Next
<img width="850" alt="Screenshot 2023-12-14 at 4 16 08 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/56fb7fce-36e6-42c1-bffb-92d88316cdbd">  

Add rule groups here add rules ->Add managed rule groups -> Select any managed rule groups that suits you and click "Add rules"  
<img width="850" alt="Screenshot 2023-12-14 at 4 16 42 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/20d2149b-56a0-4049-9000-ed874ae2a7c1">

Now leave the rest to ddefault enable for no matching request and click "Next" and prioritize your rules here and click "next"
<img width="850" alt="Screenshot 2023-12-14 at 4 31 22 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/cd61b74c-b950-4943-bcd3-fcb5b8297ffa">

Configure your cloud watch metrics for the rules you want and enable or disable the sampled requests  
<img width="850" alt="Screenshot 2023-12-14 at 4 33 02 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/2b769fed-d8d8-4fc2-b206-7f06b29a6ef0">

Now click "Next" to review your Web ACL and after analysing if everything is fine then click "Create Web ACL"   

Your application firewall is successfully implemented now and you can modify the rule groups or any other connfigs according to your requirements you can check the logs metrics on the cloud watch for the WAF

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

Run
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

## Before Implementation Results

Before implementing the security measures, assess the server's security posture and record relevant metrics.  

A basic testing can be done usig the below commands
```bash
curl -X GET "https://domain_url/page?param=<script>alert('XSS')</script>"
```
```bash
curl -X GET -d "username=admin' OR '1'='1'&password=password" https://domain_url/login
```
It will  return the below outputs respectively
<img width="850" alt="Screenshot 2023-12-13 at 12 53 53 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/79a38d7b-1719-4968-b98f-f4a5203508fd">

<img width="850" alt="Screenshot 2023-12-13 at 12 59 48 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/fe52755d-f96e-43d3-b138-58a912bd6b18">

## After Implementation Results

After implementing the security measures, reassess the server's security posture and record the improvements.  

Again run the same above commands
```bash
curl -X GET "https://domain_url/page?param=<script>alert('XSS')</script>"
```
```bash
curl -X GET -d "username=admin' OR '1'='1'&password=password" https://domain_url/login
```
This time the results will be the different  
<img width="850" alt="Screenshot 2023-12-13 at 12 59 05 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/6122ef76-22f2-42d0-80b2-9e471c0ca955">

<img width="850" alt="Screenshot 2023-12-14 at 11 50 17 AM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/e7708727-44f4-4aab-a446-602ac1dc761e">



### CloudWatch for Monitoring and Logging

CloudWatch is configured to monitor and log Nginx container activities. The Nginx container logs are stored in a persistent volume accessible by CloudWatch for centralized logging.

#### Monitoring: 

**Step 1:** Install and Configure the CloudWatch Agent  

Download the CloudWatch Agent:
```bash
sudo yum update -y
sudo yum install amazon-cloudwatch-agent
```
Configure the CloudWatch Agent:
```bash
vim /opt/aws/amazon-cloudwatch-agent/bin/config.json
```
Copy and paste the below json in the file now  
```json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "append_dimensions": {
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}",
      "InstanceId": "${aws:InstanceId}",
      "InstanceType": "${aws:InstanceType}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ]
      },
      "cpu": {
        "totalcpu": false,
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "disk": {
        "measurement": [
          "used_percent",
          "inodes_free"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "NginxAccessLogs",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "NginxErrorLogs",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
```
Run below command to bootstrap the ClouWatch Agent this will automatically place the config file and test the configs
```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
```
Check the Cloud Watch agent status now 
```bash
systemctl status amazon-cloudwatch-agent
```
Check the Cloudwatch config status  
```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```
Below commands can also be used for starting and stopping the clouwatch metrics  
```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a stop
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start
```
Now after a short time it will start sending your configured matrics to the cloudwatch and you can chek your server metrics by following the below    

Go to AWS Console -> Cloud Watch -> metrics ->All metrics ->custom namespaces  and select any metric group to check that

<img width="850" alt="Screenshot 2023-12-15 at 3 50 58 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/f3b8a79b-3e14-46bc-9836-727455b2ff0b">  

once these are visible you can set alarms for your server metrics along with SNS that will send you the Email or SMS notifications  

#### Creating Alarms with trigger to AWS SNS  

To create alarms go to the AWS ->Cloud Watch ->Alarms ->All Alarms ->Create Alarms ->Select Metric  ->CWAgent and select any metric group  
<img width="850" alt="Screenshot 2023-12-15 at 4 00 53 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/8f173edd-995c-4d0c-a1e2-b3a739e4e001">  

Now select the any metric you wanted to set alarm for in my case I am setting this for the Disk space usage  
<img width="850" alt="Screenshot 2023-12-15 at 4 02 16 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/563a257f-7cc9-43fb-8e78-4c2a940ffd18">

After clicking select metric it will show you the Alarm configuration page  
<img width="850" alt="Screenshot 2023-12-15 at 4 06 45 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/3b52d5a6-5d9f-43ad-a522-530fd634e42f">  

Verify the configs for Alarm and if any modification is required you can channge it accordingly and in the conditions tab select Static ->Graeter and enter the threshold value you wnat to trigger the alarm and click Next (you can also set the timer for the situation in this phase).   
<img width="850" alt="Screenshot 2023-12-15 at 4 07 07 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/40083255-b1c2-4808-9b40-47e6b4471a2b">  

Then in the notifications section select In Alarm ->Create new SNS topic(If don't have any existing) -> Topic name and enter the email on which you wnated to get the notifications of any anomaly -> Create Topic and select Next

<img width="850" alt="Screenshot 2023-12-15 at 6 33 09 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/991779cd-6a87-40c9-8080-7fe8a0077ae6">

In this page enter the naem for your Alarm and Add the any description for the email and then press Next and After reviewing the Details press Create Alarm  
  
<img width="850" alt="Screenshot 2023-12-15 at 6 38 11 PM" src="https://github.com/Cloud-Automation-Partner/Security-Implementations/assets/151637997/e85f7f7c-114f-4d01-ad1e-fd237f803186">

Your CloudWatch monitoring along with the SNS topic to send notifications is setup now you can test the solution

#### Logging:  

We have implemented Nginx logs to be published to the CloudWacth  

**Quick Steps**  
1- Attaching an IAM Role to instance  
2- Install CloudWatch Logs Agent  
3- Configure CloudWatch Logs Agent  

**Step 1: Attaching an IAM Role to instance**    

From AWS EC2 Console page, right click the selected instance →Instance Settings →Attach/Replace IAM Role, if you haven’t created the IAM Role, create a new one or append to existing role as the following policy actions:

```json
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
        ],
        "Resource": [
            "arn:aws:logs:*:*:*"
        ]
    }]
}
```
**Step 2: Install CloudWatch Logs Agent**  

```bash
yum install awslogs
systemctl start awslogsd.service 
systemctl enabled awslogsd.service
```
Go to /etc/awslogs and make changes to awscli.conf file, change region were your EC2 Instance is located eg: us-east-1    

```bash
vim /etc/awscli.conf
```

**Step 3: Configure CloudWatch Logs Agent**  

Edit /var/awslogs/etc/awslogs.conf file which will have default log path from previous step, you can just remove that and only have NGINX logs path setup as shown below:   

```ini
[/var/log/nginx/access.log]
datetime_format = %d/%b/%Y:%H:%M:%S %z
file = /var/log/nginx/access.log
buffer_duration = 5000
log_stream_name = access.log
initial_position = end_of_file
log_group_name = /ec2/nginx/logs

[/var/log/nginx/error.log]
datetime_format = %Y/%m/%d %H:%M:%S
file = /var/log/nginx/error.log
buffer_duration = 5000
log_stream_name = error.log
initial_position = end_of_file
log_group_name = /ec2/nginx/logs
```
Last step is by restarting the service:
```bash
sudo service awslogs restart
```
- **Persistent Volume**: The persistent volume for Nginx logs is configured to allow CloudWatch to access and collect logs from containers for monitoring purposes.

## Conclusion

This README provides an overview of the security implementations on your AWS EC2 instance. Regularly monitor and update security configurations to adapt to evolving threats and ensure the ongoing protection of your application and infrastructure.
