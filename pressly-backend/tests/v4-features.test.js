import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const read = path => readFile(resolve(root, path), 'utf8');

test('template designs use five distinct presentation systems', async () => {
  const [css, backend] = await Promise.all([
    read('styles.css'),
    read('pressly-backend/src/app.js')
  ]);
  const presentations = [
    ['navy', 'Manrope', 'classic'],
    ['teal', 'DM Sans', 'announcement'],
    ['violet', 'Georgia', 'program'],
    ['gold', 'Trebuchet MS', 'achievement'],
    ['blue', 'Arial', 'bulletin']
  ];
  const signatures = new Set(presentations.map(value => value.join('|')));
  assert.equal(signatures.size, 5);
  for (const [theme, font, format] of presentations) {
    assert.match(css, new RegExp(`\\.template-card\\.theme-${theme}`));
    assert.match(css, new RegExp(`\\.template-paper\\.theme-${theme}`));
    assert.ok(backend.includes(`theme:'${theme}',font:'${font}',format:'${format}'`));
  }
});

test('dictation enumerates alternatives safely and exposes speech languages', async () => {
  const app = await read('app.js');
  assert.ok(app.includes('Array.from({length:result.length},(_,index)=>result[index])'));
  assert.ok(app.includes('id="speechLanguage"'));
  assert.ok(app.includes("if(e.target.id==='speechLanguage')localStorage.setItem('pressly.speechLanguage',e.target.value)"));
});

test('image generation is opt-in, returned with candidate, and persisted for saved notes', async () => {
  const [app, backend, migration] = await Promise.all([
    read('app.js'),
    read('pressly-backend/src/app.js'),
    read('pressly-backend/image_migration.sql')
  ]);
  assert.ok(app.includes('name="includeImage"'));
  assert.ok(app.includes('body:body({...data,includeImage})'));
  assert.ok(backend.includes("req.body.includeImage?await generateEventImage(f,req.body.templateKey):null"));
  assert.ok(backend.includes("INSERT INTO press_note_images (press_note_id,mime_type,image_data)"));
  assert.ok(backend.includes('generatedImage:await readNoteImage(pool,row.id)'));
  assert.match(migration, /CREATE TABLE IF NOT EXISTS press_note_images/);
});
