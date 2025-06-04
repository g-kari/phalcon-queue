# 🔒 Security Configuration Guide

## Overview
This guide provides security configuration recommendations for the phalcon-queue package.

## Environment Variables Setup

Create a `.env` file with the following secure configuration:

```bash
# Database Configuration
DB_ADAPTER=Mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USERNAME=phalcon_queue_user
DB_PASSWORD=your_very_secure_password_here
DB_NAME=phalcon_queue
DB_CHARSET=utf8mb4

# Redis Configuration  
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password
REDIS_DB_INDEX=1
REDIS_TIMEOUT=5.0

# Application Security
PHALCON_QUEUE_DEBUG=false
LOG_SENSITIVE_DATA=false
ALLOWED_JOB_CLASSES="Phalcon\\Queue\\Jobs\\Job,Phalcon\\Queue\\Jobs\\AsyncJob"

# SSL/TLS Configuration
REDIS_SSL_ENABLED=false
REDIS_SSL_CERT_PATH=/path/to/cert.pem
REDIS_SSL_KEY_PATH=/path/to/key.pem

DB_SSL_ENABLED=false
DB_SSL_CA_PATH=/path/to/ca.pem
DB_SSL_CERT_PATH=/path/to/cert.pem
DB_SSL_KEY_PATH=/path/to/key.pem
```

## Secure CLI Configuration

Update your `extra/cli.php` to use environment variables:

```php
<?php declare(strict_types=1);

use Phalcon\Di\FactoryDefault\Cli as CliDI;
use Symfony\Component\Console\Application as Console;

// Load environment variables
if (file_exists(__DIR__ . '/../.env')) {
    $lines = file(__DIR__ . '/../.env', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos($line, '=') !== false && strpos($line, '#') !== 0) {
            list($key, $value) = explode('=', $line, 2);
            $_ENV[trim($key)] = trim($value);
        }
    }
}

require_once __DIR__ . '/../vendor/autoload.php';

// Dependency Injector
$di = new CliDI();

// Secure configuration
$di->setShared('config', function () {
    return new \Phalcon\Config\Config([
        'database' => [
            'adapter'  => $_ENV['DB_ADAPTER'] ?? 'Mysql',
            'host'     => $_ENV['DB_HOST'] ?? '127.0.0.1',
            'port'     => (int)($_ENV['DB_PORT'] ?? 3306),
            'username' => $_ENV['DB_USERNAME'] ?? '',
            'password' => $_ENV['DB_PASSWORD'] ?? '',
            'dbname'   => $_ENV['DB_NAME'] ?? '',
            'charset'  => $_ENV['DB_CHARSET'] ?? 'utf8mb4',
            // SSL Configuration
            'options'  => [
                PDO::MYSQL_ATTR_SSL_CA => $_ENV['DB_SSL_CA_PATH'] ?? null,
                PDO::MYSQL_ATTR_SSL_CERT => $_ENV['DB_SSL_CERT_PATH'] ?? null,  
                PDO::MYSQL_ATTR_SSL_KEY => $_ENV['DB_SSL_KEY_PATH'] ?? null,
                PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false,
            ]
        ],
        'redis' => [
            'host'     => $_ENV['REDIS_HOST'] ?? '127.0.0.1',
            'port'     => (int)($_ENV['REDIS_PORT'] ?? 6379),
            'password' => $_ENV['REDIS_PASSWORD'] ?? null,
            'timeout'  => (float)($_ENV['REDIS_TIMEOUT'] ?? 5.0),
            'ssl'      => [
                'enabled'   => (bool)($_ENV['REDIS_SSL_ENABLED'] ?? false),
                'cert_file' => $_ENV['REDIS_SSL_CERT_PATH'] ?? null,
                'key_file'  => $_ENV['REDIS_SSL_KEY_PATH'] ?? null,
            ]
        ],
        'queues' => [
            'adapter'     => 'redis',
            'dbIndex'     => (int)($_ENV['REDIS_DB_INDEX'] ?? 1),
            'debug'       => (bool)($_ENV['PHALCON_QUEUE_DEBUG'] ?? false),
            'supervisors' => [
                [
                    'queue'           => 'default',
                    'processes'       => 10,
                    'tries'           => 3,
                    'timeout'         => 180,
                    'balanceMaxShift' => 2,
                    'balanceCooldown' => 3,
                    'debug'           => (bool)($_ENV['PHALCON_QUEUE_DEBUG'] ?? false)
                ]
            ]
        ],
        'security' => [
            'allowedJobClasses' => explode(',', $_ENV['ALLOWED_JOB_CLASSES'] ?? ''),
            'logSensitiveData'  => (bool)($_ENV['LOG_SENSITIVE_DATA'] ?? false),
            'debugMode'         => (bool)($_ENV['PHALCON_QUEUE_DEBUG'] ?? false),
        ]
    ]);
});

// Secure database service
$di->setShared('db', function () use ($di) {
    $config = $di->get('config');

    $options = array_filter($config->database->options->toArray());
    
    return new \Phalcon\Db\Adapter\Pdo\Mysql([
        'adapter'  => $config->database->adapter,
        'host'     => $config->database->host,
        'port'     => $config->database->port,
        'username' => $config->database->username,
        'password' => $config->database->password,
        'dbname'   => $config->database->dbname,
        'charset'  => $config->database->charset,
        'options'  => $options
    ]);
});

// Secure Redis service
$di->setShared('redis', function () use ($di) {
    $config = $di->get('config');
    $redis = new \Redis();
    
    $context = null;
    if ($config->redis->ssl->enabled) {
        $context = stream_context_create([
            'ssl' => [
                'local_cert'        => $config->redis->ssl->cert_file,
                'local_pk'          => $config->redis->ssl->key_file,
                'verify_peer'       => true,
                'verify_peer_name'  => true,
            ]
        ]);
    }
    
    $redis->connect(
        $config->redis->host,
        $config->redis->port,
        $config->redis->timeout,
        null,
        0,
        0,
        $context ? ['stream' => $context] : []
    );
    
    if ($config->redis->password) {
        $redis->auth($config->redis->password);
    }
    
    return $redis;
});

$console = new Console('Phalcon Queue Management', '1.0.0');

$console->addCommands([
    (new \Phalcon\Queue\Commands\ExampleCommand())->setDi($di),
    (new \Phalcon\Queue\Commands\ListFailedJobCommand())->setDi($di),
    (new \Phalcon\Queue\Commands\RetryFailedJobCommand())->setDi($di),
    (new \Phalcon\Queue\Commands\RestartQueueCommand())->setDi($di),
    (new \Phalcon\Queue\Commands\ForceStopQueueCommand())->setDi($di),
]);

$console->run();
```

## Docker Security Configuration

### docker-compose.yml
```yaml
version: '3.8'

services:
  app:
    build: .
    environment:
      - DB_HOST=mysql
      - DB_USERNAME=phalcon_user
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - REDIS_HOST=redis
      - REDIS_PASSWORD_FILE=/run/secrets/redis_password
    secrets:
      - db_password
      - redis_password
    networks:
      - phalcon_network

  mysql:
    image: mysql:8.0
    environment:
      - MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql_root_password
      - MYSQL_DATABASE=phalcon_queue
      - MYSQL_USER=phalcon_user  
      - MYSQL_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - mysql_root_password
      - db_password
    volumes:
      - mysql_data:/var/lib/mysql
      - ./mysql/ssl:/etc/mysql/ssl:ro
    command: --ssl-ca=/etc/mysql/ssl/ca.pem --ssl-cert=/etc/mysql/ssl/server-cert.pem --ssl-key=/etc/mysql/ssl/server-key.pem
    networks:
      - phalcon_network

  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD} --tls-port 6380 --port 0 --tls-cert-file /etc/redis/tls/redis.crt --tls-key-file /etc/redis/tls/redis.key --tls-ca-cert-file /etc/redis/tls/ca.crt
    volumes:
      - redis_data:/data
      - ./redis/tls:/etc/redis/tls:ro
    networks:
      - phalcon_network

secrets:
  db_password:
    file: ./secrets/db_password.txt
  mysql_root_password:
    file: ./secrets/mysql_root_password.txt
  redis_password:
    file: ./secrets/redis_password.txt

volumes:
  mysql_data:
  redis_data:

networks:
  phalcon_network:
    driver: bridge
```

## Production Deployment Checklist

### Pre-Deployment Security Checklist

- [ ] Remove all hardcoded credentials
- [ ] Configure environment variables
- [ ] Enable SSL/TLS for database connections
- [ ] Enable SSL/TLS for Redis connections
- [ ] Set debug mode to false
- [ ] Configure proper file permissions (644 for files, 755 for directories)
- [ ] Set up log rotation and monitoring
- [ ] Configure firewall rules
- [ ] Enable database audit logging
- [ ] Set up intrusion detection
- [ ] Configure backup encryption

### Runtime Security Monitoring

```bash
# Log monitoring for security events
tail -f /var/log/phalcon-queue.log | grep -E "(CRITICAL|ERROR|FAILED|UNAUTHORIZED)"

# Monitor for suspicious activity
watch "ps aux | grep phalcon-queue | wc -l"

# Check for unusual network connections
netstat -an | grep ":6379\|:3306"
```

### Security Headers for Web Interface (if applicable)

```php
// Add security headers
header('X-Frame-Options: DENY');
header('X-Content-Type-Options: nosniff');
header('X-XSS-Protection: 1; mode=block');
header('Strict-Transport-Security: max-age=31536000; includeSubDomains');
header('Content-Security-Policy: default-src \'self\'');
header('Referrer-Policy: strict-origin-when-cross-origin');
```

## Incident Response Plan

### In Case of Security Breach

1. **Immediate Actions**
   - Stop all queue processing
   - Isolate affected systems
   - Change all passwords and API keys
   - Review access logs

2. **Investigation**
   - Analyze logs for unauthorized access
   - Check for data exfiltration
   - Identify compromised accounts

3. **Recovery**
   - Apply security patches
   - Restore from clean backups
   - Update security configurations
   - Resume operations with monitoring

4. **Post-Incident**
   - Document lessons learned
   - Update security procedures
   - Conduct security training
   - Schedule security audit

## Security Testing

Run the security scanner regularly:

```bash
# Run automated security scan
./security-scan.sh

# Run composer security audit
composer audit

# Run static analysis (if configured)
vendor/bin/phpstan analyse
vendor/bin/psalm
```

## Contact Information

For security issues, please contact:
- Security Team: security@yourcompany.com
- Emergency: +1-XXX-XXX-XXXX

## References

- [OWASP PHP Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/PHP_Configuration_Cheat_Sheet.html)
- [Redis Security](https://redis.io/topics/security)
- [MySQL Security](https://dev.mysql.com/doc/refman/8.0/en/security.html)
- [Phalcon Security](https://docs.phalcon.io/latest/security/)