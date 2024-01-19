<?php declare(strict_types=1);

namespace App\Enums;

use BenSampo\Enum\Enum;

/**
 * @method static static OptionOne()
 * @method static static OptionTwo()
 * @method static static OptionThree()
 */
final class SystemConfig extends Enum
{
    const userName = "angelica";
    const userEmail = "demouser@mail.com";
    const password = "123456789";

    const installedServices = ["nginx","php","mysql","redis","supervisor"];
    const installedPhpVersion = ["8.2","8.1"];
    const defaultPhpVersion = "8.1";



}
