// env.json is written by Terraform's user_data on the EC2 instance.
// Locally (no env.json) the banner shows "LOCAL".
fetch("env.json", { cache: "no-store" })
  .then((r) => (r.ok ? r.json() : Promise.reject()))
  .then((env) => {
    const banner = document.getElementById("env-banner");
    banner.textContent = `${env.environment.toUpperCase()} · ${env.region} · ${env.app_version}`;
    banner.classList.add(env.environment);
    document.getElementById("deploy-info").textContent =
      `Deployed by ${env.deployed_by} · version ${env.app_version}`;
  })
  .catch(() => {
    document.getElementById("env-banner").textContent = "LOCAL";
  });
