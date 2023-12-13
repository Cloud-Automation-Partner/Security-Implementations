# Stage 1: Build Vue.js app
FROM node:14 as vue-builder

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
ENV HOST=0.0.0.0
RUN npm run build

# Stage 2: Build ModSecurity and its Nginx connector
FROM alpine:3.18 as modsecurity-builder

# Install necessary packages for building ModSecurity
RUN apk --no-cache add \
    git \
    build-base \
    automake \
    autoconf \
    libtool \
    pcre-dev \
    linux-headers \
    lua5.3 \
    lua5.3-dev \
    openssl \
    openssl-dev\
    libstdc++

# Clone and build ModSecurity
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity.git /ModSecurity
WORKDIR /ModSecurity
RUN git submodule init
RUN git submodule update
RUN ./build.sh
RUN ./configure
RUN make
RUN make install

# Clone OWASP CRS
RUN git clone --depth 1 https://github.com/coreruleset/coreruleset.git /usr/local/modsecurity/owasp-crs
RUN mv /usr/local/modsecurity/owasp-crs/crs-setup.conf.example /usr/local/modsecurity/owasp-crs/crs-setup.conf
RUN mv /usr/local/modsecurity/owasp-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example /usr/local/modsecurity/owasp-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf

# Clone and build ModSecurity Nginx connector
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /ModSecurity-nginx

# Stage 3: Build Nginx with ModSecurity support
FROM alpine:3.18 as nginx-builder

# Copy ModSecurity libs and includes
COPY --from=modsecurity-builder /usr/local/modsecurity /usr/local/modsecurity
COPY --from=modsecurity-builder /ModSecurity-nginx /ModSecurity-nginx

# Install Nginx build dependencies
RUN apk add --no-cache \
    pcre-dev \
    zlib-dev \
    openssl-dev \
    linux-headers \
    build-base

# Download and unpack Nginx source
RUN wget http://nginx.org/download/nginx-1.24.0.tar.gz \
    && tar zxvf nginx-1.24.0.tar.gz \
    && rm nginx-1.24.0.tar.gz

# Build Nginx with ModSecurity dynamic module
WORKDIR /nginx-1.24.0
RUN ./configure --with-compat --add-dynamic-module=/ModSecurity-nginx \
    && make modules \
    && make install

# Stage 4: Build final image with Nginx and Vue.js
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache \
    lua5.3 \
    pcre \
    openssl\
    libstdc++\
    nginx

# Copy ModSecurity and Nginx binaries
COPY --from=modsecurity-builder /usr/local/modsecurity /usr/local/modsecurity
COPY --from=nginx-builder /usr/local/nginx /usr/local/nginx

# (Optional) Add Nginx sbin to PATH
#ENV PATH="/usr/local/nginx/sbin:${PATH}"

# Add ModSecurity Nginx module and configuration
COPY --from=nginx-builder /nginx-1.24.0/objs/ngx_http_modsecurity_module.so /etc/nginx/modules/
COPY modsec/ /etc/nginx/modsec


# Include OWASP CRS
RUN echo "Include /usr/local/modsecurity/owasp-crs/crs-setup.conf" >> /usr/local/modsecurity/modsecurity.conf
RUN echo "Include /usr/local/modsecurity/owasp-crs/rules/*.conf" >> /usr/local/modsecurity/modsecurity.conf

# Create Nginx log directories
#RUN mkdir -p /var/log/nginx
#RUN touch /var/log/nginx/access.log
#RUN touch /var/log/nginx/error.log

# Copy the custom Nginx configuration file
COPY default.conf /etc/nginx/http.d/default.conf
#COPY nginx.conf /etc/nginx/nginx.conf

# Copy your Vue.js code to the Nginx web root
WORKDIR /usr/share/nginx/html
COPY --from=vue-builder /app/dist .


# Expose the Nginx port
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
