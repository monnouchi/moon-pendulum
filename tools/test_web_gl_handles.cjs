const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../game/scripts/web_gl_handles.gd'), 'utf8');
const script = source.match(/const SCRIPT = """\n([\s\S]*?)\n"""/)[1];
const names = ['buffers','vaos','syncs','textures','shaders','programs',
  'framebuffers','renderbuffers','queries','samplers','contexts','uniforms','transformFeedbacks'];
const GL = {counter:1, getNewId(table) {
  const id = this.counter++;
  while (table.length < id) table.push(null);
  return id;
}};
for (const name of names) GL[name] = [];
const removed = [], GLctx = {};
for (const method of ['deleteBuffer','deleteVertexArray','deleteSync']) {
  GLctx[method] = function(object) {
    assert.equal(this, GLctx, 'The original WebGL receiver must be retained');
    removed.push(object);
  };
}
const context = {GL, GLctx, window:{}};
assert.equal(vm.runInNewContext(script, {}), false, 'An unsupported template stays untouched');
assert.equal(vm.runInNewContext(script, context), true);
const allocator = GL.getNewId;
assert.equal(vm.runInNewContext(script, context), true);
assert.equal(GL.getNewId, allocator, 'Repeated install cannot wrap the allocator again');
const make = name => {
  const object = {name:GL.getNewId(GL[name])};
  for (const tableName of names) assert.ok(!GL[tableName][object.name], 'Live handles stay globally unique');
  GL[name][object.name] = object;
  return object;
};
const drop = (name, method, object) => {
  GLctx[method](object);
  // The stock Emscripten wrapper clears its table after the native delete.
  GL[name][object.name] = null;
};
const texture = make('textures'), live = make('buffers');
for (let i = 0; i < 100000; ++i) {
  const name = ['buffers','vaos','syncs'][i%3];
  const method = ['deleteBuffer','deleteVertexArray','deleteSync'][i%3];
  const object = make(name);
  drop(name, method, object);
}
assert.equal(GL.counter, 4, 'Repeated releases keep the virtual handle high-water mark bounded');
assert.equal(GL.textures[texture.name], texture);
assert.equal(GL.buffers[live.name], live);
assert.ok(context.window.moonPendulumGLHandles.reused > 99990);

const pending = make('buffers');
GLctx.deleteBuffer(pending);
const beforeClear = make('vaos');
assert.notEqual(beforeClear.name, pending.name, 'A handle cannot be reused before the stock table is cleared');
GL.buffers[pending.name] = null;
const alien = {name:live.name};
GLctx.deleteBuffer(alien);
const another = make('syncs');
assert.notEqual(another.name, live.name, 'A foreign object cannot release an owned live handle');
GLctx.deleteBuffer(null);
assert.ok(removed.includes(null), 'Null deletion retains the original WebGL behavior');
drop('vaos','deleteVertexArray',beforeClear);
GLctx.deleteVertexArray(beforeClear);
const reused = make('buffers'), next = make('vaos');
assert.notEqual(reused.name, next.name, 'Duplicate deletions cannot queue the same ID twice');
const released = make('syncs');
drop('syncs','deleteSync',released);
const otherType = {name:released.name};
GL.textures[released.name] = otherType;
const guarded = make('buffers');
assert.notEqual(guarded.name, released.name, 'A queued ID occupied by another object type must be skipped');
assert.equal(GL.textures[released.name], otherType);
const feedbackReleased = make('buffers');
drop('buffers','deleteBuffer',feedbackReleased);
GL.transformFeedbacks[feedbackReleased.name] = {name:feedbackReleased.name};
assert.notEqual(make('syncs').name, feedbackReleased.name, 'Transform feedback handles also remain isolated');
console.log('PASS: WebGL handle reuse, 100000 mixed allocations, live-object isolation and deletion lifecycle');
