<?php

return [
    'username' => env('PLATFORM_ADMIN_USER'),
    'password_hash' => env('PLATFORM_ADMIN_PASSWORD_HASH'),
    'writes_enabled' => env('PLATFORM_WRITES_ENABLED', false),
];
