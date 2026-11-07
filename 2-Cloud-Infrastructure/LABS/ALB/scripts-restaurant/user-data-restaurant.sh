#!/bin/bash
# File: scripts/user-data-restaurant.sh
# Purpose : EC2 user data for Lab 9 (ALB introduction) - restaurant version.
#           Installs Apache and publishes a one-page static web site for a small (fictional)
#           restaurant. A small "served by" badge at the bottom shows WHICH instance and
#           WHICH Availability Zone answered, so you can still see the load balancer at work.
# Paste   : EC2 -> Launch instances -> Advanced details -> User data
#           (the first line of the box must be exactly #!/bin/bash)
set -euo pipefail

dnf -y install httpd

# ---- Instance identity (IMDSv2) ----------------------------------------------
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
md() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }
INSTANCE_ID=$(md instance-id)
AZ=$(md placement/availability-zone)
PRIVATE_IP=$(md local-ipv4)

# ---- The web site (quoted heredoc: nothing is expanded, placeholders are replaced below) ----
cat > /var/www/html/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Maison Lumière · Bistro</title>
<style>
  :root { --cream:#fbf6ee; --ink:#2b2118; --muted:#7a6a5a; --accent:#b4532a; --line:#eadfce; }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--cream); color:var(--ink); font-family: Georgia, "Times New Roman", serif; line-height:1.55; }
  header { background:linear-gradient(rgba(43,33,24,.65),rgba(43,33,24,.75)), radial-gradient(circle at 30% 20%, #c9733f, #5a2f1a);
           color:#fff; text-align:center; padding:72px 20px 56px; }
  header h1 { margin:0; font-size:clamp(2.2rem,6vw,3.6rem); letter-spacing:.04em; font-weight:normal; }
  header p { margin:10px 0 24px; font-style:italic; color:#f3e6d6; }
  .btn { display:inline-block; padding:10px 22px; border:1px solid #fff; color:#fff; text-decoration:none; border-radius:999px;
         font-family: system-ui, sans-serif; font-size:.95rem; }
  nav { display:flex; justify-content:center; gap:28px; padding:14px; border-bottom:1px solid var(--line);
        font-family: system-ui, sans-serif; font-size:.95rem; position:sticky; top:0; background:var(--cream); }
  nav a { color:var(--ink); text-decoration:none; }
  main { max-width:960px; margin:0 auto; padding:24px 20px 40px; }
  section { padding:28px 0; border-bottom:1px solid var(--line); }
  h2 { font-weight:normal; font-size:1.8rem; margin:0 0 6px; color:var(--accent); }
  .sub { color:var(--muted); margin:0 0 18px; font-style:italic; }
  .menu { display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); gap:10px 40px; }
  .menu h3 { font-family: system-ui, sans-serif; font-size:.8rem; letter-spacing:.12em; text-transform:uppercase; color:var(--muted); margin:14px 0 6px; }
  .dish { display:flex; justify-content:space-between; gap:12px; padding:6px 0; border-bottom:1px dotted var(--line); }
  .dish small { display:block; color:var(--muted); font-size:.85rem; }
  .price { white-space:nowrap; font-weight:bold; }
  .cols { display:grid; grid-template-columns:repeat(auto-fit,minmax(240px,1fr)); gap:24px; }
  table { border-collapse:collapse; width:100%; font-family: system-ui, sans-serif; font-size:.95rem; }
  td { padding:6px 0; border-bottom:1px solid var(--line); }
  td:last-child { text-align:right; }
  footer { text-align:center; padding:24px 20px 32px; color:var(--muted); font-family: system-ui, sans-serif; font-size:.85rem; }
  .served { display:inline-block; margin-top:12px; padding:6px 14px; border-radius:999px; background:var(--ink); color:#fff; font-size:.8rem; }
  .served b { color:#f2b38f; }
</style>
</head>
<body>
<header>
  <h1>Maison Lumière</h1>
  <p>French-inspired bistro · fresh, local, made in-house every day</p>
  <a class="btn" href="#contact">Book a table</a>
</header>

<nav><a href="#menu">Menu</a><a href="#hours">Hours</a><a href="#contact">Contact</a></nav>

<main>
  <section id="menu">
    <h2>Our menu</h2>
    <p class="sub">Seasonal dishes, changed every month.</p>
    <div class="menu">
      <div>
        <h3>Starters</h3>
        <div class="dish"><div>French onion soup<small>Gruyère crouton, slow-cooked onions</small></div><span class="price">$11</span></div>
        <div class="dish"><div>Goat cheese salad<small>Honey, walnuts, mixed greens</small></div><span class="price">$13</span></div>
        <div class="dish"><div>Baked brie<small>Fig jam, toasted baguette</small></div><span class="price">$14</span></div>
        <h3>Desserts</h3>
        <div class="dish"><div>Crème brûlée<small>Vanilla bean</small></div><span class="price">$9</span></div>
        <div class="dish"><div>Chocolate mousse<small>Dark chocolate, sea salt</small></div><span class="price">$9</span></div>
      </div>
      <div>
        <h3>Mains</h3>
        <div class="dish"><div>Steak frites<small>Grilled striploin, peppercorn sauce</small></div><span class="price">$32</span></div>
        <div class="dish"><div>Coq au vin<small>Red wine, mushrooms, mashed potatoes</small></div><span class="price">$27</span></div>
        <div class="dish"><div>Grilled salmon<small>Lemon butter, seasonal vegetables</small></div><span class="price">$29</span></div>
        <div class="dish"><div>Ratatouille (vegan)<small>Provençal vegetables, herbed quinoa</small></div><span class="price">$21</span></div>
        <div class="dish"><div>Croque-monsieur<small>Ham, béchamel, green salad</small></div><span class="price">$18</span></div>
      </div>
    </div>
  </section>

  <section id="hours">
    <h2>Opening hours</h2>
    <div class="cols">
      <table>
        <tr><td>Monday</td><td>Closed</td></tr>
        <tr><td>Tuesday – Thursday</td><td>11:30 – 22:00</td></tr>
        <tr><td>Friday – Saturday</td><td>11:30 – 23:00</td></tr>
        <tr><td>Sunday (brunch)</td><td>10:00 – 15:00</td></tr>
      </table>
      <p>Lunch specials Tuesday to Friday.<br>Private dining for up to 20 guests.<br>Gluten-free and vegan options available.</p>
    </div>
  </section>

  <section id="contact">
    <h2>Find us</h2>
    <div class="cols">
      <p>123 Example Street<br>Toronto, ON<br>(fictional restaurant for an AWS lab)</p>
      <p>Reservations: (555) 010-0199<br>hello@maisonlumiere.example</p>
    </div>
  </section>
</main>

<footer>
  © Maison Lumière · Lab 9 demo site
  <br>
  <span class="served">Served by <b>__INSTANCE_ID__</b> · <b>__AZ__</b> · __PRIVATE_IP__</span>
</footer>
</body>
</html>
HTML

sed -i -e "s/__INSTANCE_ID__/${INSTANCE_ID}/" -e "s/__AZ__/${AZ}/" -e "s/__PRIVATE_IP__/${PRIVATE_IP}/" /var/www/html/index.html

# Tiny page for the target group health check
echo "OK" > /var/www/html/health.html

systemctl enable --now httpd
