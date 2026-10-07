<?php
// nginx/index.php - Operations Hub with Active Directory LDAP Authentication
session_start();

$domain_controllers = ['10.0.3.10', '10.0.3.11']; // Reemplaza con las IPs reales de tus DCs si son distintas
$domain_suffix = '@corp.local';

$error_message = '';

// Procesar el formulario de Login
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['username']) && isset($_POST['password'])) {
    $username = trim($_POST['username']);
    $password = $_POST['password'];

    if (empty($username) || empty($password)) {
        $error_message = 'Please enter both username and password.';
    } else {
        // Asegurar el formato UPN para Active Directory (ej. jgarcia@corp.local)
        $ldap_user = (strpos($username, '@') === false) ? $username . $domain_suffix : $username;
        
        $authenticated = false;
        
        // Intentar autenticar contra los DCs disponibles (Alta Disponibilidad)
        foreach ($domain_controllers as $dc) {
            $ldap_conn = @ldap_connect($dc);
            if ($ldap_conn) {
                ldap_set_option($ldap_conn, LDAP_OPT_PROTOCOL_VERSION, 3);
                ldap_set_option($ldap_conn, LDAP_OPT_REFERRALS, 0);
                
                // Intentar el Bind (autenticación)
                if (@ldap_bind($ldap_conn, $ldap_user, $password)) {
                    $_SESSION['authenticated'] = true;
                    $_SESSION['username'] = explode('@', $ldap_user)[0];
                    $authenticated = true;
                    @ldap_close($ldap_conn);
                    break;
                }
                @ldap_close($ldap_conn);
            }
        }
        
        if (!$authenticated) {
            $error_message = 'Invalid domain credentials. Access denied.';
        }
    }
}

// Procesar el Logout
if (isset($_GET['action']) && $_GET['action'] === 'logout') {
    session_destroy();
    header('Location: /index.php');
    exit;
}

// --- VISTA 1: SI NO ESTÁ AUTENTICADO, MOSTRAR RECUADRO DE LOGIN ---
if (!isset($_SESSION['authenticated']) || $_SESSION['authenticated'] !== true):
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TAI Labs | Operations Sign In</title>
    <style>
        :root {
            --bg-dark: #090D16;
            --panel-bg: #111827;
            --accent-blue: #3B82F6;
            --accent-cyan: #06B6D4;
            --text-main: #F3F4F6;
            --text-muted: #9CA3AF;
            --error-red: #EF4444;
        }
        body {
            font-family: 'Inter', system-ui, sans-serif;
            background-color: var(--bg-dark);
            color: var(--text-main);
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .login-card {
            background-color: var(--panel-bg);
            border: 1px solid #1F2937;
            border-radius: 0.75rem;
            padding: 3rem 2.5rem;
            width: 100%;
            max-width: 400px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5);
        }
        h1 {
            font-size: 1.4rem;
            text-align: center;
            margin-bottom: 0.5rem;
            font-weight: 800;
        }
        h1 span {
            background: linear-gradient(to right, var(--accent-blue), var(--accent-cyan));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .subtitle {
            text-align: center;
            color: var(--text-muted);
            font-size: 0.85rem;
            margin-bottom: 2rem;
        }
        .form-group {
            margin-bottom: 1.25rem;
        }
        label {
            display: block;
            font-size: 0.85rem;
            color: var(--text-muted);
            margin-bottom: 0.5rem;
            font-weight: 500;
        }
        input {
            width: 100%;
            padding: 0.75rem;
            background: #090D16;
            border: 1px solid #1F2937;
            border-radius: 0.375rem;
            color: #FFF;
            box-sizing: border-box;
            font-size: 0.95rem;
        }
        input:focus {
            border-color: var(--accent-cyan);
            outline: none;
        }
        .btn-submit {
            width: 100%;
            padding: 0.75rem;
            background: linear-gradient(to right, var(--accent-blue), var(--accent-cyan));
            border: none;
            border-radius: 0.375rem;
            color: white;
            font-weight: 600;
            cursor: pointer;
            margin-top: 1rem;
            font-size: 0.95rem;
        }
        .error-box {
            background: rgba(239, 68, 68, 0.1);
            border: 1px solid var(--error-red);
            color: #FCA5A5;
            padding: 0.75rem;
            border-radius: 0.375rem;
            font-size: 0.85rem;
            margin-bottom: 1.5rem;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="login-card">
        <h1>TAI LABS <span>PORTAL</span></h1>
        <div class="subtitle">Berlin HQ Operations Single Sign-On (Active Directory)</div>
        
        <?php if (!empty($error_message)): ?>
            <div class="error-box"><?php echo htmlspecialchars($error_message); ?></div>
        <?php endif; ?>

        <form action="/index.php" method="POST">
            <div class="form-group">
                <label for="username">Domain Username</label>
                <input type="text" id="username" name="username" placeholder="e.g., jgarcia" required autocomplete="off">
            </div>
            <div class="form-group">
                <label for="password">Domain Password</label>
                <input type="password" id="password" name="password" placeholder="••••••••" required>
            </div>
            <button type="submit" class="btn-submit">Sign In</button>
        </form>
    </div>
</body>
</html>
<?php 
exit;
endif; 

// --- VISTA 2: SI ESTÁ AUTENTICADO, MOSTRAR EL INTERFAZ DE OPERACIONES ---
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TAI Labs | Operations & Routing Hub</title>
    <style>
        :root {
            --bg-dark: #090D16;
            --panel-bg: #111827;
            --accent-blue: #3B82F6;
            --accent-cyan: #06B6D4;
            --text-main: #F3F4F6;
            --text-muted: #9CA3AF;
            --status-green: #10B981;
        }
        body {
            font-family: 'Inter', system-ui, sans-serif;
            margin: 0;
            padding: 0;
            background-color: var(--bg-dark);
            color: var(--text-main);
            line-height: 1.6;
        }
        header {
            background-color: rgba(17, 24, 39, 0.8);
            backdrop-filter: blur(12px);
            border-bottom: 1px solid #1F2937;
            padding: 1rem 2rem;
        }
        .header-container {
            max-width: 1200px;
            margin: 0 auto;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        header h1 {
            margin: 0;
            font-size: 1.25rem;
            font-weight: 800;
            letter-spacing: 1px;
        }
        header h1 span {
            background: linear-gradient(to right, var(--accent-blue), var(--accent-cyan));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .user-menu {
            display: flex;
            align-items: center;
            gap: 1rem;
            font-size: 0.9rem;
        }
        .user-badge {
            background: #1F2937;
            padding: 0.3rem 0.8rem;
            border-radius: 4px;
            font-family: monospace;
            color: var(--accent-cyan);
            border: 1px solid #374151;
        }
        .btn-logout {
            color: #EF4444;
            text-decoration: none;
            font-weight: 600;
        }
        .container {
            max-width: 1200px;
            margin: 4rem auto;
            padding: 0 2rem;
        }
        .welcome-box {
            margin-bottom: 3rem;
        }
        .welcome-box h2 { font-size: 2.2rem; margin: 0 0 0.5rem; font-weight: 700; }
        .welcome-box p { color: var(--text-muted); margin: 0; font-size: 1.1rem; }
        
        .services-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 2rem;
        }
        .service-card {
            background-color: var(--panel-bg);
            border: 1px solid #1F2937;
            border-radius: 0.75rem;
            padding: 2rem;
            transition: border-color 0.2s ease;
        }
        .service-card:hover { border-color: rgba(6, 182, 212, 0.3); }
        .service-card h3 {
            margin-top: 0;
            font-size: 1.3rem;
            color: #FFF;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .status-indicator {
            display: inline-block;
            width: 8px;
            height: 8px;
            background-color: var(--status-green);
            border-radius: 50%;
            box-shadow: 0 0 8px var(--status-green);
        }
        .service-card p {
            color: var(--text-muted);
            font-size: 0.95rem;
            margin: 0.5rem 0 1.5rem;
        }
        .endpoint-box {
            background: #090D16;
            padding: 0.8rem;
            border-radius: 0.5rem;
            font-family: monospace;
            font-size: 0.9rem;
            color: var(--accent-cyan);
            border: 1px solid #1F2937;
        }
        .footer-hub {
            margin-top: 5rem;
            border-top: 1px solid #1F2937;
