<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Server extends Model
{
    protected $table = 'servers';
    protected $fillable = [
        'ip',
        'name',
        'ssh_password',
        'db_password',
        'php',
    ];
}
