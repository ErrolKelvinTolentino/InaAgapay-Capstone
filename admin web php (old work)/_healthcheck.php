<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once __DIR__ . '/../api/db.php';

echo 'DB OK<br>';
var_dump($conn instanceof mysqli);
