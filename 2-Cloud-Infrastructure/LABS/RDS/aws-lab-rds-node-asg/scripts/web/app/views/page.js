// File: scripts/web/app/views/page.js
// HTML rendering for the student registry. Same page as the Lab 6 Python app.
// Every value coming from the database or the request goes through esc() (no XSS).
'use strict';

const esc = (v) =>
  String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const CSS = `
  :root { --bg:#f5f7fb; --card:#fff; --ink:#1d2433; --muted:#5b6475; --line:#e3e7ef;
          --brand:#ff9900; --navy:#232f3e; --ok:#1e7e34; --err:#b42318; }
  * { box-sizing: border-box; }
  body { margin:0; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; background:var(--bg); color:var(--ink); }
  header { background:var(--navy); color:#fff; padding:18px 24px; border-bottom:4px solid var(--brand); }
  header h1 { margin:0; font-size:1.35rem; } header p { margin:4px 0 0; color:#c9d1dc; font-size:.9rem; }
  main { max-width:1150px; margin:24px auto; padding:0 16px; display:grid; gap:20px; grid-template-columns: 2fr 1fr; }
  .card { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:18px 20px; }
  .full { grid-column: 1 / -1; }
  h2 { font-size:1.05rem; margin:0 0 12px; }
  table { width:100%; border-collapse:collapse; font-size:.9rem; }
  th, td { text-align:left; padding:8px 6px; border-bottom:1px solid var(--line); }
  th { color:var(--muted); font-weight:600; font-size:.8rem; text-transform:uppercase; letter-spacing:.03em; }
  dl { display:grid; grid-template-columns: auto 1fr; gap:6px 12px; margin:0; font-size:.86rem; }
  dt { color:var(--muted); } dd { margin:0; font-family: ui-monospace, Menlo, Consolas, monospace; word-break:break-all; }
  form { display:grid; gap:10px; }
  input, select, button { font:inherit; padding:9px 10px; border:1px solid var(--line); border-radius:8px; }
  button { background:var(--brand); border-color:var(--brand); color:#111; font-weight:600; cursor:pointer; }
  .flash { padding:12px 14px; border-radius:8px; font-size:.92rem; }
  .flash.ok { background:#e8f5ec; color:var(--ok); } .flash.error { background:#fdecea; color:var(--err); }
  .badge { display:inline-block; padding:2px 8px; border-radius:999px; background:#eef2f8; font-size:.8rem; }
  .az { display:inline-block; padding:3px 10px; border-radius:999px; background:var(--brand); color:#111; font-weight:700; }
  .ver { display:inline-block; padding:3px 10px; border-radius:999px; background:#fff; color:#111; font-weight:700; }
  code { background:#eef2f8; padding:1px 5px; border-radius:4px; }
  .note { font-size:.82rem; color:var(--muted); }
  @media (max-width: 860px) { main { grid-template-columns: 1fr; } }`;

function render({ data, info, az, version, hint, flashType, flashMsg }) {
  const courses = data.courses.length
    ? data.courses.map((c) => `
        <tr><td><span class="badge">${esc(c.code)}</span></td><td>${esc(c.title)}</td><td>${esc(c.track)}</td>
            <td>${esc(c.hours)}</td><td>${esc(c.enrolled)}</td><td>${esc(Number(c.completed))}</td></tr>`).join('')
    : '<tr><td colspan="6">No data.</td></tr>';
  const students = data.students.length
    ? data.students.map((s) => `
        <tr><td>${esc(s.id)}</td><td>${esc(s.full_name)}</td><td>${esc(s.email)}</td>
            <td>${esc(s.city)}</td><td>${esc(s.courses)}</td><td>${esc(s.joined)}</td></tr>`).join('')
    : '<tr><td colspan="6">No data.</td></tr>';
  const options = data.courses.map((c) => `<option value="${esc(c.code)}">${esc(c.code)} · ${esc(c.title)}</option>`).join('');
  const details = Object.entries(info).map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join('\n      ');
  const flash = flashMsg ? `<div class="flash ${flashType === 'ok' ? 'ok' : 'error'} full">${esc(flashMsg)}</div>` : '';
  const dbError = data.error ? `
  <div class="card full">
    <div class="flash error"><strong>Cannot reach the database.</strong> ${esc(data.error)}</div>
    <p><strong>Hint:</strong> ${esc(hint)}</p>
    <p>Test from this web server (Session Manager): <code>nc -zv ${esc(info['DB endpoint'])} 3306</code></p>
  </div>` : '';

  return `<!doctype html>
<!-- File: scripts/web/app/views/page.js (rendered by server.js) -->
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Pacific Learning Co. · Student Registry</title>
<style>${CSS}
</style>
</head>
<body>
<header>
  <h1>Pacific Learning Co. · Student Registry</h1>
  <p>Node.js · Express · ALB → Auto Scaling group → RDS Proxy → Amazon RDS for MySQL · served from
     <span class="az">${esc(az)}</span> <span class="ver">v${esc(version)}</span></p>
</header>
<main>
${flash}${dbError}
  <section class="card">
    <h2>Courses</h2>
    <table>
      <thead><tr><th>Code</th><th>Title</th><th>Track</th><th>Hours</th><th>Enrolled</th><th>Completed</th></tr></thead>
      <tbody>${courses}
      </tbody>
    </table>
  </section>

  <aside class="card">
    <h2>Served by</h2>
    <dl>
      ${details}
    </dl>
    <p class="note">Refresh the page to be routed to another instance of the Auto Scaling group.</p>
  </aside>

  <section class="card">
    <h2>Students (latest 50)</h2>
    <table>
      <thead><tr><th>#</th><th>Name</th><th>Email</th><th>City</th><th>Courses</th><th>Joined</th></tr></thead>
      <tbody>${students}
      </tbody>
    </table>
  </section>

  <aside class="card">
    <h2>Register a student</h2>
    <form method="post" action="/students">
      <input name="full_name" placeholder="Full name" required maxlength="100">
      <input name="email" type="email" placeholder="Email" required maxlength="120">
      <input name="city" placeholder="City" maxlength="60">
      <select name="course_code">
        <option value="">— Enrol in a course (optional) —</option>
        ${options}
      </select>
      <button type="submit">Register</button>
    </form>
    <p class="note">Path of the write: browser → ALB → web instance (ASG) → RDS Proxy → RDS, TLS end to end.</p>
  </aside>

</main>
</body>
</html>
`;
}

module.exports = { render, esc };
