export const meta = {
  name: 'slices-wave',
  description: 'Run one wave of slices: coder then reviewer per slice, up to 3 rounds, with evidence per acceptance criterion',
  whenToUse: 'From the slices skill, to run a wave of two or more independent slices of an approved plan',
  phases: [
    { title: 'Code', detail: 'coder agent per slice, proves each acceptance criterion' },
    { title: 'Review', detail: 'reviewer agent per slice, acceptance criteria first' },
  ],
}

// args: { epic, repo_path, wave, slices: [{ id, goal, out_of_scope, acceptance: [{id, command, expected}], touches, isolation }] }
const MAX_ROUNDS = 3

const CODER_SCHEMA = {
  type: 'object',
  properties: {
    acceptance: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          command: { type: 'string' },
          output: { type: 'string' },
          pass: { type: 'boolean' },
        },
        required: ['id', 'command', 'output', 'pass'],
      },
    },
    files_changed: { type: 'array', items: { type: 'string' } },
    branch: { type: 'string' },
    head: { type: 'string' },
    worktree_path: { type: 'string' },
    decisions: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          chosen: { type: 'string' },
          over: { type: 'string' },
          why: { type: 'string' },
          revert: { type: 'string' },
        },
        required: ['chosen', 'over', 'why', 'revert'],
      },
    },
    stop: {
      type: 'object',
      properties: { gate: { type: 'string' }, reason: { type: 'string' } },
      required: ['gate', 'reason'],
    },
    not_checked: { type: 'string' },
    signals: { type: 'array', items: { type: 'string' } },
  },
  required: ['acceptance', 'files_changed', 'decisions', 'not_checked', 'signals'],
}

const DECIDE_OR_STOP = `Decide reversible choices inside the slice's goal yourself: take the simplest option that meets the goal and report it in decisions. Fill stop, and leave the change unfinished, only before you add a dependency, change a public API or contract outside the slice, delete data, touch security, permissions or production infrastructure, launch a run expected to take more than 20 minutes, or when an acceptance criterion cannot be met as written.`

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    acceptance: {
      type: 'array',
      items: {
        type: 'object',
        properties: { id: { type: 'string' }, pass: { type: 'boolean' }, evidence: { type: 'string' } },
        required: ['id', 'pass', 'evidence'],
      },
    },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          n: { type: 'number' },
          severity: { type: 'string', enum: ['P0', 'P1', 'P2'] },
          title: { type: 'string' },
          location: { type: 'string' },
          problem: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['n', 'severity', 'title', 'location', 'problem', 'fix'],
      },
    },
    verdict: { type: 'string', enum: ['ship', 'fix'] },
    verdict_line: { type: 'string' },
    not_checked: { type: 'string' },
    signals: { type: 'array', items: { type: 'string' } },
  },
  required: ['acceptance', 'findings', 'verdict', 'verdict_line', 'not_checked', 'signals'],
}

function sliceBlock(s) {
  const acs = s.acceptance.map(a => `  ${a.id}: \`${a.command}\` -> ${a.expected}`).join('\n')
  return [
    `Slice ${s.id} of epic "${args.epic}"`,
    `Goal: ${s.goal}`,
    `Out of scope: ${s.out_of_scope}`,
    `Touches: ${s.touches}`,
    `Acceptance:\n${acs}`,
  ].join('\n')
}

function workspaceRule(s, previous) {
  if (s.isolation === 'worktree' && previous && previous.worktree_path) {
    return `Work in ${previous.worktree_path}, on branch ${previous.branch}. Commit your fixes there and report the branch, the new head SHA and the worktree path.`
  }
  if (s.isolation === 'worktree') {
    return `You run in your own git worktree. Commit your work on a branch named slices/${args.epic}-${s.id} and report the branch, the head SHA and the worktree path (git rev-parse --show-toplevel).`
  }
  return `Work in ${args.repo_path}. Other slices run in the same checkout at the same time: edit only the files this slice touches, and do not commit, stash, reset or switch branches.`
}

function coderPrompt(s, findings, previous) {
  const fix = findings
    ? `\n\nThe reviewer asked for fixes. Address each one, then re-prove every acceptance criterion:\n${JSON.stringify(findings, null, 2)}`
    : ''
  return `${sliceBlock(s)}\n\n${workspaceRule(s, previous)}\n\nImplement this slice. Prove each acceptance criterion by running its command; put the real output in your report.\n\n${DECIDE_OR_STOP}${fix}`
}

function reviewerPrompt(s, coded, earlierFindings) {
  const where = coded.branch
    ? `Review branch ${coded.branch} at ${coded.head} against its merge base, from ${args.repo_path}.`
    : `Review the uncommitted changes in ${args.repo_path} to these files only: ${coded.files_changed.join(', ')}.`
  // The coder's worktree holds the branch; reviewing from it avoids depending on the shared checkout's state.
  const from = coded.worktree_path ? ` Run git from ${coded.worktree_path}.` : ''
  const earlier = earlierFindings
    ? `\n\nThe findings of the earlier round:\n${JSON.stringify(earlierFindings, null, 2)}`
    : ''
  return `${sliceBlock(s)}\n\n${where}${from}\n\nThe coder's report:\n${JSON.stringify(coded, null, 2)}${earlier}\n\nRe-run each acceptance criterion command yourself before you pass it.`
}

async function runSlice(s) {
  const signals = []
  const decisions = []
  let findings = null
  let coded = null
  let review = null
  for (let round = 1; round <= MAX_ROUNDS; round++) {
    coded = await agent(coderPrompt(s, findings, coded), {
      label: `code ${s.id} r${round}`,
      phase: 'Code',
      agentType: 'coder',
      schema: CODER_SCHEMA,
      ...(s.isolation === 'worktree' && round === 1 ? { isolation: 'worktree' } : {}),
    })
    if (!coded) return { id: s.id, status: 'blocked', reason: 'coder died', rounds: round, decisions, signals }
    signals.push(...coded.signals.map(x => `[coder] ${x}`))
    decisions.push(...coded.decisions.map(d => ({ ...d, round })))
    if (coded.stop) {
      log(`${s.id}: stopped at gate "${coded.stop.gate}"`)
      return { id: s.id, status: 'stopped', gate: coded.stop.gate, reason: coded.stop.reason, rounds: round, coded, decisions, signals }
    }

    review = await agent(reviewerPrompt(s, coded, findings), {
      label: `review ${s.id} r${round}`,
      phase: 'Review',
      agentType: 'reviewer',
      schema: REVIEW_SCHEMA,
    })
    if (!review) return { id: s.id, status: 'blocked', reason: 'reviewer died', rounds: round, coded, decisions, signals }
    signals.push(...review.signals.map(x => `[reviewer] ${x}`))

    const acsPass = review.acceptance.length > 0 && review.acceptance.every(a => a.pass)
    if (review.verdict === 'ship' && acsPass) {
      log(`${s.id}: ship after ${round} round(s)`)
      const follow_ups = review.findings.filter(f => f.severity === 'P2')
      return { id: s.id, status: 'done', rounds: round, coded, review, follow_ups, decisions, signals }
    }
    findings = review.findings
    log(`${s.id}: round ${round} -> ${review.verdict_line}`)
  }
  return { id: s.id, status: 'blocked', reason: `no ship after ${MAX_ROUNDS} rounds`, rounds: MAX_ROUNDS, coded, review, decisions, signals }
}

log(`epic ${args.epic}, wave ${args.wave}: ${args.slices.map(s => s.id).join(', ')}`)
const results = await pipeline(args.slices, runSlice)
return { epic: args.epic, wave: args.wave, slices: results.map((r, i) => r || { id: args.slices[i].id, status: 'blocked', reason: 'stage threw' }) }
