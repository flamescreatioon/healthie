<?php

use App\Http\Controllers\Api\V1\AccountController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\ExportController;
use App\Http\Controllers\Api\V1\MeasurementController;
use App\Http\Controllers\Api\V1\SyncController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::post('auth/register', [AuthController::class, 'register'])->middleware('throttle:auth');
    Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:auth');

    Route::middleware('auth:sanctum')->group(function (): void {
        Route::post('auth/logout', [AuthController::class, 'logout']);

        Route::apiResource('measurements', MeasurementController::class)
            ->parameters(['measurements' => 'id']);

        Route::post('sync/upload', [SyncController::class, 'upload'])->middleware('throttle:sync');
        Route::get('sync/changes', [SyncController::class, 'changes'])->middleware('throttle:sync');

        Route::get('exports/measurements', [ExportController::class, 'measurements']);
        Route::delete('account', [AccountController::class, 'destroy']);
    });
});
