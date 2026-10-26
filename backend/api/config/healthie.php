<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Healthie domain configuration
    |--------------------------------------------------------------------------
    |
    | Export schema version travels with every export payload so imports can
    | validate before writing. Retention controls the scheduled pruning of
    | accounts whose tokens show no activity; the same period must appear in
    | the privacy policy. Override with RETENTION_INACTIVE_MONTHS in .env.
    |
    */

    'export_schema_version' => 1,

    'retention_inactive_months' => (int) env('RETENTION_INACTIVE_MONTHS', 24),

];
