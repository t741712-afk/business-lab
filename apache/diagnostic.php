<?php
echo "=== DIAGNÓSTICO DE ENTORNO ===<br>";
echo "Usuario actual: " . shell_exec('whoami') . "<br>";
echo "Directorio actual: " . shell_exec('pwd') . "<br>";
?>