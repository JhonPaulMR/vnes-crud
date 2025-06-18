<?php
// Conexão com o banco de dados usando variáveis de ambiente
$host = getenv('DB_HOST');
$db_name = getenv('DB_DATABASE');
$username = getenv('DB_USERNAME');
$password = getenv('DB_PASSWORD');
$conn = new mysqli($host, $username, $password, $db_name);

// Verifica a conexão
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
?>