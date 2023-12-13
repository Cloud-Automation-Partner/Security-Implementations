# Security Implementation Ec2 & Docker

This README provides an overview of the security implementations on your AWS EC2 Linux instance running a Dockerized application. The security measures include the use of Fail2Ban for Nginx and SSH, AWS Web Application Firewall (WAF), and ModSecurity with the OWASP Core Rule Set.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Security Implementations](#security-implementations)
   - [Fail2Ban](#fail2ban)
   - [AWS WAF](#aws-waf)
   - [ModSecurity with OWASP Core Rule Set](#modsecurity-with-owasp-core-rule-set)
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

- **Configuration**: The Fail2Ban configuration files can be found in the `/etc/fail2ban/` directory. Adjustments to the configuration can be made in `jail.local`.

- **Logs Monitoring**: Fail2Ban is set up to monitor Nginx and SSH logs, reacting to repetitive failed login attempts and other specified patterns.

### AWS WAF

AWS Web Application Firewall (WAF) has been configured to protect your web application from common web exploits.

- **AWS Console**: The AWS WAF configuration can be managed through the AWS Management Console.

- **Rules and Conditions**: Custom rules and conditions have been set up to filter and block malicious traffic based on specified conditions.

### ModSecurity with OWASP Core Rule Set

ModSecurity, along with the OWASP Core Rule Set (CRS), has been implemented as a web application firewall to protect against various web application attacks.

- **Docker Image**: The ModSecurity Docker image with the OWASP CRS is pulled from the Docker Hub (`owasp/modsecurity-crs`) and integrated into the Vue.js Alpine container.

- **Configuration**: The ModSecurity configuration files are present in the `/etc/modsecurity/` directory. Adjustments can be made in the `modsecurity.conf` file.

## Before Implementation Results

Before implementing the security measures, assess the server's security posture and record relevant metrics. This may include logs of failed login attempts, Nginx access logs, and any other relevant information.

Add any specific metrics, logs, or details relevant to your application and infrastructure.

## After Implementation Results

After implementing the security measures, reassess the server's security posture and record the improvements. Include metrics such as reduced failed login attempts, blocked malicious IP addresses, and any other relevant information.

Compare the results with the before-implementation metrics to gauge the effectiveness of the implemented security measures.

## Conclusion

This README provides an overview of the security implementations on your AWS EC2 instance. Regularly monitor and update security configurations to adapt to evolving threats and ensure the ongoing protection of your application and infrastructure.
