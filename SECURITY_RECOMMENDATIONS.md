# 🔒 セキュリティ改善推奨事項

## 即座に対応すべき修正

### 1. 環境変数を使用したデータベース認証情報の保護

**現在のコード** (`extra/cli.php`):
```php
'database' => [
    'adapter'  => 'Mysql',
    'host'     => '127.0.0.1',
    'username' => 'root',
    'password' => 'polat',  // 🔴 Critical: ハードコード
    'dbname'   => 'phalcon',
    'charset'  => 'utf8',
],
```

**推奨修正**:
```php
'database' => [
    'adapter'  => $_ENV['DB_ADAPTER'] ?? 'Mysql',
    'host'     => $_ENV['DB_HOST'] ?? '127.0.0.1',
    'username' => $_ENV['DB_USERNAME'] ?? 'root',
    'password' => $_ENV['DB_PASSWORD'] ?? '',
    'dbname'   => $_ENV['DB_NAME'] ?? 'phalcon',
    'charset'  => $_ENV['DB_CHARSET'] ?? 'utf8',
],
```

**環境変数ファイル** (`.env.example`):
```bash
DB_ADAPTER=Mysql
DB_HOST=127.0.0.1
DB_USERNAME=root
DB_PASSWORD=your_secure_password_here
DB_NAME=phalcon
DB_CHARSET=utf8

# Redis設定
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB_INDEX=1
```

### 2. 安全なシリアライゼーションの実装

**現在のコード** (`lib/Tasks/WorkerTask.php`):
```php
$jobClass = unserialize($this->job->payload);  // 🔴 危険
```

**推奨修正**:
```php
$jobClass = unserialize($this->job->payload, [
    'allowed_classes' => [
        \Phalcon\Queue\Jobs\Job::class,
        \Phalcon\Queue\Jobs\AsyncJob::class,
        // 他の許可されたジョブクラス
    ]
]);
```

**または JSON ベースのアプローチ**:
```php
// シリアライゼーション時
$payload = json_encode([
    'class' => get_class($job),
    'data'  => $job->toArray()
]);

// デシリアライゼーション時  
$payloadData = json_decode($this->job->payload, true);
if (in_array($payloadData['class'], $allowedClasses)) {
    $jobClass = new $payloadData['class']($payloadData['data']);
}
```

### 3. 例外情報の安全な処理

**現在のコード** (`lib/Connectors/PDOStorage.php`):
```php
'exception' => json_encode([
    'class'   => get_class($exception),
    'message' => $exception->getMessage(),
    'code'    => $exception->getCode(),
    'file'    => $exception->getFile(),      // 🔶 情報漏洩リスク
    'line'    => $exception->getLine(),      // 🔶 情報漏洩リスク
    'trace'   => $exception->getTrace(),     // 🔶 情報漏洩リスク
])
```

**推奨修正**:
```php
'exception' => json_encode([
    'class'   => get_class($exception),
    'message' => $exception->getMessage(),
    'code'    => $exception->getCode(),
    // 本番環境では詳細情報を除外
    'file'    => $this->isDebugMode() ? $exception->getFile() : null,
    'line'    => $this->isDebugMode() ? $exception->getLine() : null,
    'trace'   => $this->isDebugMode() ? $exception->getTrace() : null,
])
```

## 中期的改善項目

### 4. 設定管理の改善

**設定クラスの作成** (`lib/Config/SecurityConfig.php`):
```php
<?php

namespace Phalcon\Queue\Config;

class SecurityConfig
{
    private bool $debugMode;
    private array $allowedJobClasses;
    private bool $logSensitiveData;

    public function __construct()
    {
        $this->debugMode = (bool)($_ENV['PHALCON_QUEUE_DEBUG'] ?? false);
        $this->allowedJobClasses = $this->loadAllowedJobClasses();
        $this->logSensitiveData = (bool)($_ENV['LOG_SENSITIVE_DATA'] ?? false);
    }

    public function isDebugMode(): bool
    {
        return $this->debugMode;
    }

    public function getAllowedJobClasses(): array
    {
        return $this->allowedJobClasses;
    }

    public function shouldLogSensitiveData(): bool
    {
        return $this->logSensitiveData;
    }

    private function loadAllowedJobClasses(): array
    {
        $classes = $_ENV['ALLOWED_JOB_CLASSES'] ?? '';
        return $classes ? explode(',', $classes) : [
            \Phalcon\Queue\Jobs\Job::class,
            \Phalcon\Queue\Jobs\AsyncJob::class,
        ];
    }
}
```

### 5. ログセキュリティの強化

**セキュアログ処理クラス** (`lib/Utils/SecureLogger.php`):
```php
<?php

namespace Phalcon\Queue\Utils;

class SecureLogger
{
    private array $sensitiveFields = [
        'password', 'token', 'secret', 'key', 'auth'
    ];

    public function sanitizeLogData(array $data): array
    {
        $sanitized = $data;
        
        foreach ($this->sensitiveFields as $field) {
            if (isset($sanitized[$field])) {
                $sanitized[$field] = '***REDACTED***';
            }
        }
        
        return $sanitized;
    }

    public function filterStackTrace(array $trace): array
    {
        // 本番環境ではスタックトレースから機密情報を除去
        return array_map(function($frame) {
            unset($frame['args']); // 引数に機密情報が含まれる可能性
            return $frame;
        }, $trace);
    }
}
```

### 6. Redisセキュリティの強化

**Redis接続設定の改善** (`lib/Connectors/Redis.php`):
```php
public function __construct()
{
    $this->redis = new RedisClient();
    
    $config = Di::getDefault()->get('config');
    
    // 接続設定
    $this->redis->connect(
        $_ENV['REDIS_HOST'] ?? '127.0.0.1',
        (int)($_ENV['REDIS_PORT'] ?? 6379),
        (float)($_ENV['REDIS_TIMEOUT'] ?? 0.0),
        null,
        0,
        0,
        ['stream' => ['verify_peer' => true]] // SSL設定
    );
    
    // 認証
    if (!empty($_ENV['REDIS_PASSWORD'])) {
        $this->redis->auth($_ENV['REDIS_PASSWORD']);
    }
    
    // データベース選択
    $this->redis->select((int)($_ENV['REDIS_DB_INDEX'] ?? 1));
}
```

## 開発プロセスの改善

### 7. セキュリティチェックの自動化

**Composer設定** (`composer.json`):
```json
{
    "require-dev": {
        "phpstan/phpstan": "^1.0",
        "psalm/psalm": "^4.0",
        "roave/security-advisories": "dev-latest",
        "phpunit/phpunit": "^9.0"
    },
    "scripts": {
        "security-check": [
            "composer audit",
            "phpstan analyse",
            "psalm --show-info=false"
        ],
        "test": "phpunit",
        "check-all": [
            "@security-check",
            "@test"
        ]
    }
}
```

**GitHub Actions設定** (`.github/workflows/security.yml`):
```yaml
name: Security Checks

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: '8.1'
        
    - name: Install dependencies
      run: composer install --no-dev --optimize-autoloader
      
    - name: Run security audit
      run: composer audit
      
    - name: Run static analysis
      run: |
        composer require --dev phpstan/phpstan
        vendor/bin/phpstan analyse lib/
```

### 8. 入力検証の強化

**バリデーションクラス** (`lib/Validators/JobValidator.php`):
```php
<?php

namespace Phalcon\Queue\Validators;

class JobValidator
{
    public function validateJobPayload(string $payload): bool
    {
        // ペイロードサイズ制限
        if (strlen($payload) > 1024 * 1024) { // 1MB制限
            throw new \InvalidArgumentException('Job payload too large');
        }
        
        // 危険なパターンの検出
        $dangerousPatterns = [
            '/eval\s*\(/i',
            '/exec\s*\(/i',
            '/system\s*\(/i',
            '/shell_exec\s*\(/i',
            '/passthru\s*\(/i'
        ];
        
        foreach ($dangerousPatterns as $pattern) {
            if (preg_match($pattern, $payload)) {
                throw new \InvalidArgumentException('Dangerous code pattern detected');
            }
        }
        
        return true;
    }
    
    public function validateQueueName(string $queue): bool
    {
        // 英数字とハイフン、アンダースコアのみ許可
        if (!preg_match('/^[a-zA-Z0-9_-]+$/', $queue)) {
            throw new \InvalidArgumentException('Invalid queue name format');
        }
        
        return true;
    }
}
```

## まとめ

これらの推奨事項を段階的に実装することで、phalcon-queueパッケージのセキュリティを大幅に向上させることができます。

**優先順位**:
1. **最優先**: 環境変数の使用、安全なシリアライゼーション
2. **高優先**: 例外情報の制限、設定管理の改善
3. **中優先**: ログセキュリティ、Redisセキュリティ
4. **継続的**: セキュリティチェックの自動化

各修正を実装後は必ずテストを実行し、既存機能に影響がないことを確認してください。