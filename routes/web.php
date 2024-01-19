<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\DashboardController;

Route::get('/', function () {
    return redirect(route('login'));
});

Route::group(['prefix' => 'dashboard', 'middleware' => ['auth:sanctum', config('jetstream.auth_session')]], function () {
    Route::get('/', [DashboardController::class, 'index'])->name('dashboard');
});
