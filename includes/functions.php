<?php
// Common functions for the application

// Function to validate and upload files
function uploadFile($file, $targetDir, $allowedTypes) {
    // Garantir que o diretório termina com uma barra
    $targetDir = rtrim($targetDir, '/') . '/';
    
    // Verificar se o diretório existe, se não, tentar criar
    if (!file_exists($targetDir)) {
        if (!mkdir($targetDir, 0755, true)) {
            return ["success" => false, "message" => "Falha ao criar o diretório $targetDir"];
        }
    }
    
    // Verificar se o diretório é gravável
    if (!is_writable($targetDir)) {
        return ["success" => false, "message" => "O diretório $targetDir não é gravável. Verifique as permissões."];
    }
    
    // Verificar erros de upload
    if ($file["error"] !== UPLOAD_ERR_OK) {
        $errorMessages = [
            UPLOAD_ERR_INI_SIZE => "O arquivo excede o tamanho máximo permitido",
            UPLOAD_ERR_FORM_SIZE => "O arquivo excede o tamanho máximo do formulário",
            UPLOAD_ERR_PARTIAL => "O arquivo foi parcialmente carregado",
            UPLOAD_ERR_NO_FILE => "Nenhum arquivo foi enviado",
            UPLOAD_ERR_NO_TMP_DIR => "Diretório temporário não encontrado",
            UPLOAD_ERR_CANT_WRITE => "Falha ao escrever no disco",
            UPLOAD_ERR_EXTENSION => "Upload interrompido por uma extensão"
        ];
        $errorMessage = $errorMessages[$file["error"]] ?? "Erro desconhecido no upload";
        return ["success" => false, "message" => $errorMessage];
    }
    
    $fileName = basename($file["name"]);
    $fileType = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));
    
    // Validar tipo de arquivo
    if (!in_array($fileType, $allowedTypes)) {
        return ["success" => false, "message" => "Tipo de arquivo inválido. Tipos permitidos: " . implode(", ", $allowedTypes)];
    }
    
    // Gerar nome de arquivo único
    $uniqueFileName = uniqid() . "." . $fileType;
    $targetFilePath = $targetDir . $uniqueFileName;
    
    // Verificar se o arquivo temporário existe e é legível
    if (!file_exists($file["tmp_name"]) || !is_readable($file["tmp_name"])) {
        return ["success" => false, "message" => "Arquivo temporário não encontrado ou não legível"];
    }
    
    // Tentar mover o arquivo
    if (move_uploaded_file($file["tmp_name"], $targetFilePath)) {
        return ["success" => true, "path" => $targetFilePath];
    } else {
        $error = error_get_last();
        $errorMessage = $error ? $error["message"] : "Erro desconhecido";
        error_log("Falha ao mover o arquivo: $errorMessage");
        return ["success" => false, "message" => "Falha ao mover o arquivo: $errorMessage"];
    }
}

// Function to get all cartridges
function getAllCartridges($conn) {
    $sql = "SELECT * FROM cartridges ORDER BY created_at DESC";
    $result = $conn->query($sql);
    $cartridges = [];
    
    if ($result->num_rows > 0) {
        while ($row = $result->fetch_assoc()) {
            $cartridges[] = $row;
        }
    }
    
    return $cartridges;
}

// Function to get a single cartridge by ID
function getCartridgeById($conn, $id) {
    $sql = "SELECT * FROM cartridges WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        return $result->fetch_assoc();
    }
    
    return false;
}

// Function to delete files from server
function deleteFile($filePath) {
    if (file_exists($filePath) && !is_dir($filePath)) {
        return unlink($filePath);
    }
    return false;
}
?>