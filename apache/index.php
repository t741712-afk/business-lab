<?php
// index.php
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Laboratories Corporation TAI | Innovación Tecnológica</title>
    <style>
        :root {
            --primary: #0F172A;
            --accent: #2563EB;
            --text: #334155;
            --light: #F8FAFC;
        }
        body {
            font-family: 'Segoe UI', system-ui, sans-serif;
            margin: 0;
            padding: 0;
            color: var(--text);
            background-color: var(--light);
        }
        header {
            background-color: var(--primary);
            color: white;
            padding: 1.5rem 2rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
        }
        header h1 {
            margin: 0;
            font-size: 1.5rem;
            letter-spacing: 1px;
            color: #E2E8F0;
        }
        header h1 span { color: var(--accent); }
        .hero {
            text-align: center;
            padding: 5rem 2rem;
            background: linear-gradient(135deg, #1E293B 0%, #0F172A 100%);
            color: white;
        }
        .hero h2 { font-size: 3rem; margin-bottom: 1rem; }
        .hero p { font-size: 1.25rem; color: #94A3B8; max-width: 600px; margin: 0 auto 2rem; }
        .btn {
            background-color: var(--accent);
            color: white;
            padding: 0.75rem 1.5rem;
            text-decoration: none;
            border-radius: 0.375rem;
            font-weight: 600;
        }
        .container { max-width: 1200px; margin: 3rem auto; padding: 0 2rem; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem; }
        .card { background: white; padding: 2rem; border-radius: 0.5rem; box-shadow: 0 1px 3px rgb(0 0 0 / 0.1); }
        .card h3 { color: var(--primary); margin-top: 0; }
        footer {
            background-color: #E2E8F0;
            padding: 2rem;
            margin-top: 5rem;
            font-size: 0.875rem;
            color: #64748B;
            border-top: 1px solid #CBD5E1;
        }
        .debug-box {
            background: #F1F5F9;
            padding: 1rem;
            border-radius: 0.25rem;
            font-family: monospace;
            margin-top: 1rem;
        }
    </style>
</head>
<body>

    <header>
        <h1>LABORATORIES CORPORATION <span>TAI</span></h1>
        <nav><a href="/info.php" style="color:#94A3B8; text-decoration:none;">System Info</a></nav>
    </header>

    <section class="hero">
        <h2>Sistemas de Alta Disponibilidad</h2>
        <p>Impulsando la infraestructura crítica y la monitorización avanzada para entornos corporativos globales.</p>
        <a href="#" class="btn">Explorar Servicios</a>
    </section>

    <main class="container">
        <div class="grid">
            <div class="card">
                <h3>Infraestructura Core</h3>
                <p>Despliegue automatizado de Controladores de Dominio y gestión centralizada de identidades.</p>
            </div>
            <div class="card">
                <h3>Monitorización Proactiva</h3>
                <p>Sistemas analíticos basados en Prometheus y telemetría en tiempo real para aplicaciones Web.</p>
            </div>
            <div class="card">
                <h3>Seguridad de Capa Web</h3>
                <p>Frontales Linux y Windows balanceados con políticas estrictas de cifrado y auditoría.</p>
            </div>
        </div>
    </main>

    <footer>
        <div style="display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap;">
            <div>
                <p>&copy; 2026 Laboratories Corporation TAI. Todos los derechos reservados.</p>
            </div>
            <div>
                <strong>Nodo de Diagnóstico:</strong>
                <div class="debug-box">
                    Host: <?php echo gethostname(); ?><br>
                    Server Date: <?php echo date('Y-m-d H:i:s'); ?><br>
                    PHP Version: <?php echo phpversion(); ?><br>
                    SERVER_ADDR: <?php echo $_SERVER['SERVER_ADDR'] ?? '?'; ?><br>
                    HTTP_HOST: <?php echo $_SERVER['HTTP_HOST'] ?? '?'; ?>
                </div>
            </div>
        </div>
    </footer>

</body>
</html>
