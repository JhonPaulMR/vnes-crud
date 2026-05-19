<?php
echo "Iniciando teste de conexão ao banco de dados...\n";

set_error_handler(function($errno, $errstr, $errfile, $errline) {
    throw new ErrorException($errstr, 0, $errno, $errfile, $errline);
});

try {
    require_once __DIR__ . '/../config/database.php';
    echo "Sucesso: Conexão com o banco de dados estabelecida.\n";
    exit(0);
} catch (Exception $e) {
    echo "Falha no teste de banco de dados: " . $e->getMessage() . "\n";
    exit(1);
}
