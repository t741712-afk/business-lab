<?php
// index.php - Laboratories Corporation TAI (Biomedicine & AI)
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Laboratories Corporation TAI | Advanced Biomedicine & AI</title>
    <style>
        :root {
            --bg-dark: #0B0F19;
            --card-bg: #111827;
            --accent-blue: #3B82F6;
            --accent-cyan: #06B6D4;
            --text-main: #F3F4F6;
            --text-muted: #9CA3AF;
        }
        body {
            font-family: 'Inter', system-ui, -apple-system, sans-serif;
            margin: 0;
            padding: 0;
            background-color: var(--bg-dark);
            color: var(--text-main);
            line-height: 1.6;
        }
        header {
            background-color: rgba(17, 24, 39, 0.8);
            backdrop-filter: blur(12px);
            position: fixed;
            width: 100%;
            top: 0;
            z-index: 100;
            border-bottom: 1px solid #1F2937;
            box-sizing: border-box;
        }
        .nav-container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 1.2rem 2rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        header h1 {
            margin: 0;
            font-size: 1.3rem;
            font-weight: 800;
            letter-spacing: 1.5px;
            background: linear-gradient(to right, #FFF, var(--text-muted));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        header h1 span {
            background: linear-gradient(to right, var(--accent-blue), var(--accent-cyan));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .hero {
            padding: 10rem 2rem 6rem;
            background: radial-gradient(circle at top right, rgba(6, 182, 212, 0.15), transparent 40%),
                        radial-gradient(circle at bottom left, rgba(59, 130, 246, 0.1), transparent 50%);
            text-align: center;
        }
        .badge {
            background: rgba(59, 130, 246, 0.1);
            border: 1px solid rgba(59, 130, 246, 0.3);
            color: #60A5FA;
            padding: 0.4rem 1rem;
            border-radius: 2rem;
            font-size: 0.85rem;
            font-weight: 600;
            display: inline-block;
            margin-bottom: 1.5rem;
            letter-spacing: 0.5px;
        }
        .hero h2 {
            font-size: 3.5rem;
            font-weight: 800;
            margin: 0 auto 1.5rem;
            max-width: 900px;
            line-height: 1.15;
            letter-spacing: -1px;
        }
        .hero h2 em {
            font-style: normal;
            background: linear-gradient(to right, #22D3EE, #3B82F6);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .hero p {
            font-size: 1.25rem;
            color: var(--text-muted);
            max-width: 700px;
            margin: 0 auto 2.5rem;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 4rem 2rem;
        }
        .section-title {
            text-align: center;
            font-size: 2rem;
            margin-bottom: 3rem;
            font-weight: 700;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 2rem;
        }
        .card {
            background-color: var(--card-bg);
            border: 1px solid #1F2937;
            padding: 2.5rem;
            border-radius: 0.75rem;
            transition: transform 0.2s ease, border-color 0.2s ease;
        }
        .card:hover {
            transform: translateY(-4px);
            border-color: rgba(6, 182, 212, 0.4);
        }
        .card h3 {
            color: #FFF;
            font-size: 1.4rem;
            margin-top: 0;
            margin-bottom: 1rem;
        }
        .card p {
            color: var(--text-muted);
            font-size: 0.975rem;
            margin: 0;
        }
        .info-hq {
            background: linear-gradient(135deg, #111827 0%, #0F172A 100%);
            border: 1px solid #1F2937;
            border-radius: 0.75rem;
            padding: 3rem;
            margin-top: 4rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 2rem;
        }
        .hq-text h3 { margin: 0 0 0.5rem; font-size: 1.7rem; }
        .hq-text p { margin: 0; color: var(--text-muted); }
        .hq-location {
            background: rgba(255,255,255,0.05);
            padding: 1rem 1.5rem;
            border-radius: 0.5rem;
            border-left: 4px solid var(--accent-cyan);
        }
        footer {
            background-color: #030712;
            padding: 4rem 2rem 2rem;
            margin-top: 8rem;
            border-top: 1px solid #1F2937;
            font-size: 0.875rem;
            color: var(--text-muted);
        }
        .footer-content {
            max-width: 1200px;
            margin: 0 auto;
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            flex-wrap: wrap;
            gap: 3rem;
        }
        .debug-box {
            background: #111827;
            border: 1px solid #1F2937;
            padding: 1.2rem;
            border-radius: 0.5rem;
            font-family: 'Fira Code', monospace;
            color: #34D399;
            margin-top: 0.5rem;
            font-size: 0.8rem;
            box-shadow: inset 0 2px 4px rgba(0,0,0,0.5);
        }
    </style>
</head>
<body>

    <header>
        <div class="nav-container">
            <h1>LABORATORIES CORPORATION <span>TAI</span></h1>
            <nav><a href="/info.php" style="color: var(--accent-cyan); text-decoration:none; font-weight:600; font-size:0.9rem;">Core Engine Info &rarr;</a></nav>
        </div>
    </header>

    <section class="hero">
        <span class="badge">PRECISION BIOMEDICINE IN THE DIGITAL ERA</span>
        <h2>Reshaping molecular therapeutics through <em>Artificial Intelligence</em></h2>
        <p>Accelerating drug discovery and cellular modeling by combining deep neural networks with advanced genetic sequencing.</p>
    </section>

    <main class="container">
        <h2 class="section-title">Strategic Research Areas</h2>
        <div class="grid">
            <div class="card">
                <h3>AI-Driven Molecular Synthesis</h3>
                <p>Predictive algorithms based on deep learning that design optimal, target-specific chemical compounds, reducing clinical screening times from years to mere days.</p>
            </div>
            <div class="card">
                <h3>Computational Genomics</h3>
                <p>Massive sequencing and predictive analysis of complex molecular variants, focused on the immediate development of personalized therapies and advanced cancer immunotherapy.</p>
            </div>
            <div class="card">
                <h3>Cellular Organ Simulation</h3>
                <p>Microscale mathematical modeling of cellular responses against novel pathogens utilizing digital twins and generative adversarial networks (GANs).</p>
            </div>
        </div>

        <div class="info-hq">
            <div class="hq-text">
                <h3>Global Innovation Headquarters</h3>
                <p>Our main facility unifies world-class data scientists and molecular biologists under one roof.</p>
            </div>
            <div class="hq-location">
                <strong>Corporation TAI GmbH</strong><br>
                Müllerstraße 178, Mitte<br>
                13353 Berlin, Germany
            </div>
        </div>
    </main>

    <footer>
        <div class="footer-content">
            <div>
                <p>&copy; 2026 Laboratories Corporation TAI. All rights reserved.<br>
                Registered in the Commercial Register of the District Court of Charlottenburg (Berlin).</p>
            </div>
            <div>
                <strong>Cluster Environment (Diagnostic Metrics):</strong>
                <div class="debug-box">
                    NODE_ID: <?php echo gethostname(); ?><br>
                    TIME_UTC: <?php echo date('Y-m-d H:i:s'); ?><br>
                    RUNTIME: PHP v<?php echo phpversion(); ?><br>
                    IP_INTERNAL: <?php echo $_SERVER['SERVER_ADDR'] ?? '0.0.0.0'; ?><br>
                    ROUTING_HOST: <?php echo $_SERVER['HTTP_HOST'] ?? 'localhost'; ?>
                </div>
            </div>
        </div>
    </footer>

</body>
</html>
