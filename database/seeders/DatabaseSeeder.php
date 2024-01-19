<?php

namespace Database\Seeders;

use App\Enums\SystemConfig;
use App\Models\Server;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // \App\Models\User::factory(10)->create();

        User::create([
            'email' => SystemConfig::userEmail,
            'password' => Hash::make(SystemConfig::password),
        ]);

        Server::create([
            'ip' => 'CHANGE_IP',
            'ssh_password' => 'CHANGE_SSH_PASSWORD',
            'db_password' => 'CHANGE_DB_PASSWORD',
        ]);
    }
}
