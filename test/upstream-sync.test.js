import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { execFileSync, spawnSync } from 'node:child_process'

const script = resolve('scripts/sync-upstream.sh')
const git = (cwd, ...args) => execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()

for (const scenario of ['fast-forward', 'diverged', 'conflict']) {
  test(`upstream sync: ${scenario}, safe repeat or rollback`, () => {
    const root = mkdtempSync(join(tmpdir(), 'cfsm-sync-test-'))
    try {
      const upstream = join(root, 'upstream')
      const fork = join(root, 'fork')
      git(root, 'init', '-b', 'main', upstream)
      git(upstream, 'config', 'user.name', 'Sync Test')
      git(upstream, 'config', 'user.email', 'test@example.invalid')
      writeFileSync(join(upstream, 'shared.txt'), 'base\n')
      git(upstream, 'add', '.')
      git(upstream, 'commit', '-m', 'base')
      git(root, 'clone', upstream, fork)
      git(fork, 'config', 'user.name', 'Sync Test')
      git(fork, 'config', 'user.email', 'test@example.invalid')
      if (scenario !== 'fast-forward') {
        writeFileSync(join(fork, scenario === 'conflict' ? 'shared.txt' : 'local.txt'), 'fork customization\n')
        git(fork, 'add', '.')
        git(fork, 'commit', '-m', 'fork customization')
      }
      const before = git(fork, 'rev-parse', 'HEAD')
      writeFileSync(join(upstream, 'shared.txt'), 'upstream update\n')
      git(upstream, 'add', '.')
      git(upstream, 'commit', '-m', 'upstream update')
      const output = join(root, 'outputs')
      const env = { ...process.env, UPSTREAM_URL: upstream, GITHUB_OUTPUT: output }
      const result = spawnSync('bash', [script], { cwd: fork, env, encoding: 'utf8' })
      if (scenario === 'conflict') {
        assert.notEqual(result.status, 0)
        assert.match(result.stdout, /shared.txt/)
        assert.equal(git(fork, 'rev-parse', 'HEAD'), before)
        assert.equal(git(fork, 'status', '--porcelain'), '')
        assert.equal(readFileSync(join(fork, 'shared.txt'), 'utf8'), 'fork customization\n')
      } else {
        assert.equal(result.status, 0, result.stderr)
        assert.match(readFileSync(output, 'utf8'), /changed=true/)
        assert.equal(readFileSync(join(fork, 'shared.txt'), 'utf8'), 'upstream update\n')
        assert.equal(git(fork, 'rev-parse', 'origin/main'), git(upstream, 'rev-parse', 'HEAD~1'), 'prepare must not push')
        if (scenario === 'diverged') assert.equal(readFileSync(join(fork, 'local.txt'), 'utf8'), 'fork customization\n')
        const after = git(fork, 'rev-parse', 'HEAD')
        const repeat = spawnSync('bash', [script], { cwd: fork, env, encoding: 'utf8' })
        assert.equal(repeat.status, 0, repeat.stderr)
        assert.match(readFileSync(output, 'utf8'), /changed=false/)
        assert.equal(git(fork, 'rev-parse', 'HEAD'), after)
      }
    } finally {
      rmSync(root, { recursive: true, force: true })
    }
  })
}
