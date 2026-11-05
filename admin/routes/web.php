<?php

use App\Http\Controllers\TenantController;
use App\Http\Middleware\AdminBasicAuth;
use Illuminate\Support\Facades\Route;

Route::middleware(AdminBasicAuth::class)->group(function () {
    Route::get('/', [TenantController::class, 'index'])->name('tenants.index');
    Route::post('/tenants', [TenantController::class, 'store'])->name('tenants.store');
    Route::delete('/tenants/{name}', [TenantController::class, 'destroy'])->name('tenants.destroy');
});
