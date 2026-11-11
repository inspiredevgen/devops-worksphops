// =============================================================================
// EN: Post ONE sticky comment per stack on the pull request, updated on every push.
//     Called from actions/github-script:  require('./scripts/ci/pr-comment.js')({github, context, core}, {...})
// FR : Publier UN commentaire persistant par pile sur la pull request, mis à jour à chaque push.
// =============================================================================
const fs = require('fs');

const MAX_PLAN = 60000; // EN: GitHub comments are limited to 65,536 characters / FR : limite de 65 536 caractères

const read = (file) => (file && fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '');
// EN: Neutralize ``` so the plan can't break out of its code block. / FR : Neutraliser ``` pour que le plan ne sorte pas de son bloc.
const fence = (text) => text.replace(/```/g, "'''");

function buildBody({ marker, title, plan, policy, policyOutcome, sha, runUrl }) {
  const summary = (plan.match(/^(Plan: .*|No changes\..*)$/m) || ['(plan output not found / sortie du plan introuvable)'])[0];
  const shown = plan.length > MAX_PLAN ? `${plan.slice(0, MAX_PLAN)}\n… truncated / tronqué: see the job log / voir le journal` : plan;
  const gate = policyOutcome === 'success' ? '✅ passed / réussie' : '❌ failed / échouée';
  return [
    `<!-- ${marker} -->`,
    `### ${title}`,
    '',
    `**${summary}**`,
    '',
    `Policy gate / Porte de politiques: ${gate}`,
    '',
    '<details><summary>Plan</summary>',
    '',
    '```text',
    fence(shown),
    '```',
    '</details>',
    '',
    '<details><summary>Policy results / Résultats des politiques</summary>',
    '',
    '```text',
    fence(policy.slice(0, 4000)) || '(none / aucun)',
    '```',
    '</details>',
    '',
    `<sub>Commit ${sha.slice(0, 7)} · [run](${runUrl})</sub>`,
  ].join('\n');
}

async function postComment({ github, context, core }, { marker, title, planFile, policyFile, policyOutcome }) {
  const { owner, repo } = context.repo;
  const issue_number = context.issue.number;
  const body = buildBody({
    marker,
    title,
    plan: read(planFile),
    policy: read(policyFile),
    policyOutcome,
    sha: context.sha,
    runUrl: `${context.serverUrl}/${owner}/${repo}/actions/runs/${context.runId}`,
  });

  const comments = await github.paginate(github.rest.issues.listComments, { owner, repo, issue_number, per_page: 100 });
  const mine = comments.find((c) => c.user && c.user.type === 'Bot' && c.body.includes(`<!-- ${marker} -->`));
  if (mine) {
    await github.rest.issues.updateComment({ owner, repo, comment_id: mine.id, body });
    core.info(`Updated comment ${mine.id}`);
  } else {
    await github.rest.issues.createComment({ owner, repo, issue_number, body });
    core.info('Created comment');
  }
}

module.exports = postComment;
module.exports.buildBody = buildBody;
