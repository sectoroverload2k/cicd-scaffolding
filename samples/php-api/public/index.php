<?php

declare(strict_types=1);

require_once __DIR__ . '/../vendor/autoload.php';

// Health check endpoint
if ($_SERVER['REQUEST_URI'] === '/health') {
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'ok',
        'version' => trim(file_get_contents(__DIR__ . '/../VERSION')),
        'timestamp' => date('c')
    ]);
    exit;
}

// Your application bootstrap here
// Example: $app = new App\Application();
// $app->run();

header('Content-Type: application/json');
echo json_encode([
    'message' => 'PHP API is running',
    'version' => trim(file_get_contents(__DIR__ . '/../VERSION'))
]);
