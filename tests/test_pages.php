<?php
echo "Iniciando teste de funções da aplicação...\n";

set_error_handler(function($errno, $errstr, $errfile, $errline) {
    throw new ErrorException($errstr, 0, $errno, $errfile, $errline);
});

try {
    require_once __DIR__ . '/../config/database.php';
    require_once __DIR__ . '/../includes/functions.php';

    $cartridges = getAllCartridges($conn);
    
    if (is_array($cartridges)) {
        echo "Sucesso: getAllCartridges retornou um array com " . count($cartridges) . " elementos.\n";
        exit(0);
    } else {
        echo "Falha: getAllCartridges não retornou um array.\n";
        exit(1);
    }
} catch (Exception $e) {
    echo "Falha no teste das funções: " . $e->getMessage() . "\n";
    exit(1);
}
