import { expect, test } from 'claude-code/testing'

test('tool.call denies from the guard child and continues after a warning', async ($, on) => {
  const writes: { path: string, text: string }[] = []
  on('session.root', () => ({ value: '/work/app' }))
  on('session.id', () => ({ value: 's-host' }))
  on('process.run', (_engine, event: { argv: string[], init?: { stdin?: string, env?: Record<string, string> } }) => {
    expect(event.argv[0]).toBe('node')
    expect(event.argv[1]).toMatch(/specnav-guard\.js$/)
    expect(event.init?.env?.SPECNAV_GATE_CALLER).toBe('mod')
    expect(event.init?.env?.PROJECT_DIR).toBe('/work/app')
    const stdin = event.init?.stdin || ''
    if (stdin.includes('rm -rf /')) {
      return {
        value: {
          exitCode: 2,
          stdout: '',
          stderr: 'SpecNav gate denied: [dangerous-command] blocked\n'
        }
      }
    }
    return {
      value: {
        exitCode: 0,
        stdout: '{"systemMessage":"SpecNav gate warning: missing"}\n',
        stderr: ''
      }
    }
  })
  on('fs.write', (_engine, event: { path: string, text: string }) => {
    writes.push(event)
    return { value: undefined }
  })
  on('tool.call', () => ({ result: { text: 'continued' } }))

  const denied = await $.tool.call({
    tool: 'Bash',
    command: 'rm -rf /',
    tool_use_id: 'toolu_host_deny'
  })
  expect(denied.deny).toBe('[dangerous-command] blocked')

  const read = await $.tool.call({
    tool: 'Read',
    file_path: 'src/app.ts',
    tool_use_id: 'toolu_host_read'
  })
  expect(read.result.text).toBe('continued')

  const warned = await $.tool.call({
    tool: 'Write',
    file_path: 'src/app.ts',
    content: 'x',
    tool_use_id: 'toolu_host_warn'
  })
  expect(warned.result.text).toBe('continued')
  const receipt = writes.find((item) => item.path.endsWith('mod-gate-toolu_host_warn.json'))
  expect(receipt?.path).toBe('/work/app/openspec/.specnav/mod-gate-toolu_host_warn.json')
  expect(JSON.parse(receipt?.text || '{}').exitCode).toBe(0)
})

test('status and doctor are immediate and the router still falls through', async ($, on) => {
  const registered: string[] = []
  const status: string[] = []
  on('session.root', () => ({ value: '/work/app' }))
  on('session.id', () => ({ value: 's-cmd' }))
  on('process.run', (_engine, event: { argv: string[] }) => {
    const script = event.argv[1] || ''
    if (script.endsWith('specnav-doctor.js')) {
      return { value: { exitCode: 0, stdout: '# SpecNav Doctor\n\n- status: ready\n', stderr: '' } }
    }
    return {
      value: {
        exitCode: 0,
        stdout: 'SpecNav: ready change=none ready=[] blockers=[]\n',
        stderr: ''
      }
    }
  })
  on('command.register', (_engine, event: { name: string }) => {
    registered.push(event.name)
    return { value: undefined }
  })
  on('ui.status', (_engine, event: { text?: string }) => {
    if (typeof event.text === 'string') status.push(event.text)
    return { value: undefined }
  })
  on('session.start', () => ({ cwd: '/work/app' }))
  on('command.run', () => ({ text: 'fell-through' }))
  on('turn.complete', () => ({ text: 'done' }))
  on('prompt.context', () => ({ blocks: [{ name: 'claudeMd', text: 'keep' }] }))

  await $.session.start({ cwd: '/work/app' })
  expect(registered).toEqual(['specnav-status', 'specnav-doctor'])
  expect(status[0]).toMatch(/^SpecNav: ready/)

  const statusResult = await $.command.run({ command: 'specnav-status', args: '' })
  expect(statusResult.text).toMatch(/^SpecNav: ready/)

  const doctor = await $.command.run({ command: 'specnav-doctor', args: '' })
  expect(doctor.text).toMatch(/SpecNav Doctor/)

  const route = await $.command.run({ command: 'specnav', args: '' })
  expect(route.text).toBe('fell-through')

  await $.turn.complete({ answer: 'done' })
  const context = await $.prompt.context({ blocks: [{ name: 'claudeMd', text: 'keep' }] })
  expect(context.blocks.map((block: { name: string }) => block.name)).toEqual(['claudeMd', 'specnav'])
})
