/** Host half of the dsh-pet-desktop bundle.
 * Owns the desktop whale process: apply() launches whale.ps1 (a transparent
 * WPF window swimming the official DeepSeek whale across the whole desktop),
 * and a registered disposer stops it when the plugin is disabled, unloaded or
 * restarted. The whale also watches the host PID and exits by itself if the
 * whole Harness goes away without running disposers.
 */

import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

const here = path.dirname(fileURLToPath(import.meta.url));

export function apply(ctx) {
  let child = null;
  let reported = false;
  const reportFailure = (message) => {
    if (reported) return;
    reported = true;
    console.warn('[dsh-pet-desktop] ' + message);
  };
  const stop = () => {
    if (!child) return;
    const running = child;
    child = null;
    try {
      running.kill();
    } catch {
      // The whale's PID watchdog is the fallback owner-cleanup path.
    }
  };

  try {
    const script = path.join(here, 'whale.ps1');
    const stateDir = path.join(process.env.APPDATA || here, 'dsh-pet');
    fs.mkdirSync(stateDir, { recursive: true });
    child = spawn(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-STA',
        '-ExecutionPolicy', 'Bypass',
        '-WindowStyle', 'Hidden',
        '-File', script,
        '-ParentPid', String(process.pid),
        '-StateFile', path.join(stateDir, 'position.json'),
      ],
      { stdio: ['ignore', 'ignore', 'pipe'], windowsHide: true },
    );
    // A failed spawn (missing PowerShell, locked-down policy) must never break
    // the profile; the error surfaces through the 'error' event only.
    const running = child;
    let stderr = '';
    running.stderr.setEncoding('utf8');
    running.stderr.on('data', (chunk) => {
      stderr = (stderr + chunk).slice(-4096);
    });
    running.on('error', (error) => {
      reportFailure('Could not launch the whale: ' + error.message);
      if (child === running) child = null;
    });
    // close fires after stderr is drained, so the final error text is available.
    running.on('close', (code) => {
      if (child !== running) return;
      child = null;
      if (code !== null && code !== 0) {
        reportFailure('Whale exited with code ' + code + (stderr.trim() ? ': ' + stderr.trim() : ''));
      }
    });
  } catch (error) {
    child = null;
    reportFailure('Could not start the whale: ' + error.message);
  }

  // Canonical cleanup registration. `ctx.effect(setup)` runs setup immediately
  // and collects its RETURN value as the disposer, which runs when the fiber is
  // disposed (plugin disable / unload / config restart). Note the host process
  // outlives a plugin disable, so this - not the whale's PID watchdog - is what
  // must stop the whale here; the watchdog only covers whole-host exits.
  if (ctx && typeof ctx.effect === 'function') {
    try {
      ctx.effect(() => stop);
    } catch {
      // Fall through to the return-value registration below.
    }
  }
  // Belt and braces: cordis also collects a function returned from apply().
  // `stop` is idempotent, so running twice from the double registration is safe.
  return stop;
}
